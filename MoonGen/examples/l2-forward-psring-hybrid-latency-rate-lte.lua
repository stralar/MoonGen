local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
local ts      = require "timestamping"
local stats   = require "stats"
local log     = require "log"
local limiter = require "software-ratecontrol"
local pipe    = require "pipe"
local ffi     = require "ffi"
local libmoon = require "libmoon"
local histogram = require "histogram"

local namespaces = require "namespaces"

local PKT_SIZE	= 60


function configure(parser)
	parser:description("Forward traffic between interfaces with moongen rate control")
	parser:option("-d --dev", "Devices to use, specify the same device twice to echo packets."):args(2):convert(tonumber)
	--parser:option("-r --rate", "Transmit rate in Mpps."):args(1):default(2):convert(tonumber)
	parser:option("-r --rate", "Forwarding rates in Mbps (two values for two links)"):args(2):convert(tonumber)
	parser:option("-t --threads", "Number of threads per forwarding direction using RSS."):args(1):convert(tonumber):default(1)
	parser:option("-l --latency", "Fixed emulated latency (in ms) on the link."):args(2):convert(tonumber):default({0,0})
	parser:option("-x --xlatency", "Extra exponentially distributed latency, in addition to the fixed latency (in ms)."):args(2):convert(tonumber):default({0,0})
	parser:option("-q --queuedepth", "Maximum number of packets to hold in the delay line"):args(2):convert(tonumber):default({0,0})
	parser:option("-o --loss", "Rate of packet drops"):args(2):convert(tonumber):default({0,0})
	parser:option("-c --concealedloss", "Rate of concealed packet drops"):args(2):convert(tonumber):default({0,0})
	parser:option("-u --catchuprate", "After a concealed loss, this rate will apply to the backed-up frames."):args(2):convert(tonumber):default({0,0})
	parser:option("-y --random", "Manipulate the receiving time by adding [0-1]ms"):args(1):convert(tonumber):default(0)
	parser:option("--short_DRX_cycle_length", "The short DRX cycle length in ms"):args(1):convert(tonumber):default(6)
	parser:option("--long_DRX_cycle_length", "The long DRX cycle length in ms"):args(1):convert(tonumber):default(12)
	parser:option("--active_time", "The active time from PDCCH in ms"):args(1):convert(tonumber):default(1)
	parser:option("--continuous_reception_inactivity_timer", "The continous reception inactivity timer in ms"):args(1):convert(tonumber):default(200)
	parser:option("--short_DRX_inactivity_timer", "The short DRX inactivity timer in ms"):args(1):convert(tonumber):default(2298)
	parser:option("--long_DRX_inactivity_timer", "The long DRX inactivity timer in ms"):args(1):convert(tonumber):default(7848)
	parser:option("--rcc_idle_cycle_length", "The RCC IDLE cycle length in ms"):args(1):convert(tonumber):default(50)
	parser:option("--rcc_connection_build_delay", "The Delay from RCC_IDLE to RCC_CONNECT in ms"):args(1):convert(tonumber):default(70)
	return parser:parse()
end


function master(args)

	if args.random ~= 0 and  args.random ~= 1 then
		print("Wrong Parameter for -y, only 0 or 1 accept")
		return
	end
	-- configure devices
	for i, dev in ipairs(args.dev) do
		args.dev[i] = device.config{
			port = dev,
			txQueues = args.threads,
			rxQueues = args.threads,
			rssQueues = 0,
			rssFunctions = {},
			txDescs = 32,
			--rxDescs = 4096,
			dropEnable = true,
			disableOffloads = true
		}
	end
	device.waitForLinks()

	-- print stats
	stats.startStatsTask{devices = args.dev}
	
	-- create the ring buffers
	-- should set the size here, based on the line speed and latency, and maybe desired queue depth
	local qdepth1 = args.queuedepth[1]
	if qdepth1 < 1 then
		qdepth1 = math.floor((args.latency[1] * args.rate[1] * 1000)/672)
	end
	local qdepth2 = args.queuedepth[2]
	if qdepth2 < 1 then
		qdepth2 = math.floor((args.latency[2] * args.rate[2] * 1000)/672)
	end
	local ring1 = pipe:newPktsizedRing(qdepth1)
	local ring2 = pipe:newPktsizedRing(qdepth2)

	local ns = namespaces:get()


	-- start the forwarding tasks
	for i = 1, args.threads do
		mg.startTask("forward", 1, ns, ring1, args.dev[1]:getTxQueue(i - 1), args.dev[1], args.rate[1], args.latency[1], args.xlatency[1], args.loss[1], args.concealedloss[1], args.catchuprate[1],
			args.short_DRX_cycle_length, args.long_DRX_cycle_length, args.active_time, args.continuous_reception_inactivity_timer, args.short_DRX_inactivity_timer, args.long_DRX_inactivity_timer, args.rcc_idle_cycle_length, args.rcc_connection_build_delay)
		if args.dev[1] ~= args.dev[2] then
			mg.startTask("forward", 2, ns, ring2, args.dev[2]:getTxQueue(i - 1), args.dev[2], args.rate[2], args.latency[2], args.xlatency[2], args.loss[2], args.concealedloss[2], args.catchuprate[2],
					args.short_DRX_cycle_length, args.long_DRX_cycle_length, args.active_time, args.continuous_reception_inactivity_timer, args.short_DRX_inactivity_timer, args.long_DRX_inactivity_timer, args.rcc_idle_cycle_length, args.rcc_connection_build_delay)

		end
	end

	-- start the receiving/latency tasks
	for i = 1, args.threads do
		mg.startTask("receive", ring1, args.dev[2]:getRxQueue(i - 1), args.dev[2], args.random == 1)
		if args.dev[1] ~= args.dev[2] then
			mg.startTask("receive", ring2, args.dev[1]:getRxQueue(i - 1), args.dev[1], args.random == 1)
		end
	end

	mg.waitForTasks()
end


function receive(ring, rxQueue, rxDev, randomON)
	--print("receive thread...")

	local tsc_hz = libmoon:getCyclesFrequency()
	local tsc_hz_ms = tsc_hz / 1000

	local bufs = memory.createBufArray()
	local count = 0
	local count_hist = histogram:new()
	local ringsize_hist = histogram:new()
	local ringbytes_hist = histogram:new()
	while mg.running() do

		count = rxQueue:recv(bufs)
		count_hist:update(count)
		--print("receive thread count="..count)
		for iix=1,count do
			local last_time = limiter:get_tsc_cycles() + (tsc_hz_ms * math.random())
			while randomON and limiter:get_tsc_cycles() < last_time do
				if not mg.running() then
					return
				end
			end

			local buf = bufs[iix]
			local ts = limiter:get_tsc_cycles()
                       	buf.udata64 = ts
		end

		if count > 0 then
			pipe:sendToPktsizedRing(ring.ring, bufs, count)
			-- print("buf count: "..count)
			ringsize_hist:update(pipe:countPktsizedRing(ring.ring))
		end
	end
	count_hist:print()
	count_hist:save("rxq-pkt-count-distribution-histogram-"..rxDev["id"]..".csv")
	ringsize_hist:print()
	ringsize_hist:save("rxq-ringsize-distribution-histogram-"..rxDev["id"]..".csv")
end

function forward(threadNumber, ns, ring, txQueue, txDev, rate, latency, xlatency, lossrate, clossrate, catchuprate,
				 short_DRX_cycle_length, long_DRX_cycle_length, active_time, continuous_reception_inactivity_timer, short_DRX_inactivity_timer, long_DRX_inactivity_timer, rcc_idle_cycle_length, rcc_connection_build_delay)
	print("forward with rate "..rate.." and latency "..latency.." and loss rate "..lossrate.." and clossrate "..clossrate.." and catchuprate "..catchuprate)
	local numThreads = 1

	local linkspeed = txDev:getLinkStatus().speed
	print("linkspeed = "..linkspeed)

	local tsc_hz = libmoon:getCyclesFrequency()
	local tsc_hz_ms = tsc_hz / 1000
	print("tsc_hz = "..tsc_hz)

	print("Thread: "..threadNumber)

	-- DRX in LTE is in RRC_IDLE or in RRC_CONNECTED mode
	-- RRC_IDLE: sleep state
	-- RRC_CONNECTED:
	ns.rcc_idle = true

	-- the RRC_CONNECTED mode got the short DRX cycle and long DRX cycle
	ns.short_DRX = false
	ns.long_DRX = false
	ns.continuous_reception = false

	local last_activity = limiter:get_tsc_cycles()

	ns.inactive_time_short_DRX_cycle = ullToNumber(last_activity)
	ns.inactive_time_long_DRX_cycle = ullToNumber(last_activity)
	ns.inactive_time_continuous_reception_cycle = ullToNumber(last_activity)
	ns.last_packet_time = ullToNumber(last_activity)

	--local continuous_reception_inactivity_time_ms = 200
	--local inactive_short_DRX_cycle_time_ms = 2500
	--local inactive_long_DRX_cycle_time_ms = 10500


	ns.first_rcc_connected = false

	local debug = false


	-- larger batch size is useful when sending it through a rate limi ter
	local bufs = memory.createBufArray()  --memory:bufArray()  --(128)
	local count = 0


	-- when there is a concealed loss, the backed-up packets can
	-- catch-up at line rate
	local catchup_mode = false


	-- between 0.32 and 2.56 sec
	local rcc_idle_cycle_length_tsc_hz_ms = rcc_idle_cycle_length * tsc_hz_ms

	local short_DRX_cycle_length_tsc_hz_ms = short_DRX_cycle_length * tsc_hz_ms
	local long_DRX_cycle_length_tsc_hz_ms = long_DRX_cycle_length * tsc_hz_ms

	local active_time_tsc_hz_ms = active_time * tsc_hz_ms

	-- will be reset after each send/received packet
	-- timer is between 1ms - 2.56sec Paper-[10]
	local inactive_continuous_reception_cycle_time = continuous_reception_inactivity_timer * tsc_hz_ms

	--local inactive_short_DRX_cycle_time = (short_DRX_inactivity_timer - continuous_reception_inactivity_timer) * tsc_hz_ms

	--local inactive_long_DRX_cycle_time = (long_DRX_inactivity_timer - short_DRX_inactivity_timer) * tsc_hz_ms

	local inactive_short_DRX_cycle_time = (short_DRX_inactivity_timer + continuous_reception_inactivity_timer) * tsc_hz_ms

	local inactive_long_DRX_cycle_time = (long_DRX_inactivity_timer + short_DRX_inactivity_timer + continuous_reception_inactivity_timer)* tsc_hz_ms

	-- 16 to 19 signalling messages
	local rcc_connection_build_delay_tsc_hz_ms = rcc_connection_build_delay * tsc_hz_ms

	-- in ms
	local concealed_resend_time = 8

	local time_stuck_in_loop = 0

	while mg.running() do
		--print("top of loop")
		-- RCC_IDLE to RCC_CONNECTED the delay
		if ns.first_rcc_connected then
			print("Build RCC_CONNECTION "..threadNumber)
			last_activity = limiter:get_tsc_cycles()
			while limiter:get_tsc_cycles() < last_activity + rcc_connection_build_delay_tsc_hz_ms do
				if not mg.running() then
					return
				end
				-- if the other thread finished the LOOP
				if not ns.first_rcc_connected then
					break
				end
			end
			ns.first_rcc_connected = false
			if time_stuck_in_loop > 0 then
				time_stuck_in_loop = time_stuck_in_loop + rcc_connection_build_delay_tsc_hz_ms
			end
			last_activity = limiter:get_tsc_cycles()
		end

		-- if the continuous_reception mode is active
		if ns.continuous_reception then
			count = pipe:recvFromPktsizedRing(ring.ring, bufs, 1)

			for iix=1,count do
				local buf = bufs[iix]

				-- get the buf's arrival timestamp and compare to current time
				--local arrival_timestamp = buf:getTimestamp()
				local arrival_timestamp = buf.udata64
				local extraDelay = 0.0
				if (xlatency > 0) then
					extraDelay = -math.log(math.random())*xlatency
				end

				-- emulate concealed losses
				local closses = 0.0
				while (math.random() < clossrate) do
					closses = closses + 1
					if (catchuprate > 0) then
						catchup_mode = true
						--print "entering catchup mode!"
					end
				end

				local send_time = arrival_timestamp
				if (closses > 0) then
					send_time = send_time + ((closses*concealed_resend_time + latency + extraDelay) * tsc_hz_ms + time_stuck_in_loop)
				else
					send_time = send_time + ((latency + extraDelay) * tsc_hz_ms + time_stuck_in_loop)
				end
				time_stuck_in_loop = 0

				local cur_time = limiter:get_tsc_cycles()
				--print("timestamps", arrival_timestamp, send_time, cur_time)
				-- spin/wait until it is time to send this frame
				-- this assumes frame order is preserved
				while limiter:get_tsc_cycles() < send_time do
					catchup_mode = false
					if not mg.running() then
						return
					end
				end

				local pktSize = buf.pkt_len + 24
				if (catchup_mode) then
					--print "operating in catchup mode!"
					buf:setDelay((pktSize) * (linkspeed/catchuprate - 1))
				else
					buf:setDelay((pktSize) * (linkspeed/rate - 1))
				end
			end

			if count > 0 then

				-- the rate here doesn't affect the result afaict.  It's just to help decide the size of the bad pkts
				txQueue:sendWithDelayLoss(bufs, rate * numThreads, lossrate, count)

				last_activity = limiter:get_tsc_cycles()
				ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())
			end
			if limiter:get_tsc_cycles() > last_activity + inactive_continuous_reception_cycle_time then
				if limiter:get_tsc_cycles() > ns.last_packet_time + inactive_continuous_reception_cycle_time then

					print("continuous_reception deactivating "..threadNumber)
					ns.continuous_reception = false

					print("short_DRX activating "..threadNumber)
					ns.short_DRX = true
				end
			end
		end

		-- RCC_CONNECTED short_DRX
		if ns.short_DRX then

			last_activity = limiter:get_tsc_cycles()

			local packet_arrival_time = 0
			local lcount = 0
			time_stuck_in_loop = 0

			-- time to wait
			while ns.short_DRX and limiter:get_tsc_cycles() < last_activity + short_DRX_cycle_length_tsc_hz_ms - active_time_tsc_hz_ms do
				lcount = pipe:countPktsizedRing(ring.ring)
				if (lcount > 0) and (packet_arrival_time == 0) then
					packet_arrival_time = limiter:get_tsc_cycles()
				end
				if not mg.running() then
					return
				end
			end

			-- save the time the packet waited
			last_activity = limiter:get_tsc_cycles()
			if (lcount > 0) then
				time_stuck_in_loop = (last_activity-packet_arrival_time)
			end

			-- T_on is active
			while ns.short_DRX and limiter:get_tsc_cycles() < last_activity + active_time_tsc_hz_ms do
				if not mg.running() then
					return
				end
				-- count = pipe:recvFromPktsizedRing(ring.ring, bufs, 1)
				count = pipe:countPktsizedRing(ring.ring)

				if count > 0 then
					print("short_DRX deactivating "..threadNumber)
					ns.short_DRX = false

					print("continuous_reception activating "..threadNumber)
					ns.continuous_reception = true

					last_activity = limiter:get_tsc_cycles()
					ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())

					break
				end
			end

			-- if the the max of interactive Time from short DRX arrived, it will be changed to long DRX
			if limiter:get_tsc_cycles() > ns.last_packet_time + inactive_short_DRX_cycle_time then
				print("short_DRX deactivating after inactive time, "..threadNumber)
				ns.short_DRX = false

				print("long_DRX activating after inactive time, "..threadNumber)
				ns.long_DRX = true
			end
		end

		-- RCC_CONNECTED long_DRX
		if ns.long_DRX then
			last_activity = limiter:get_tsc_cycles()

			local packet_arrival_time = 0
			local lcount = 0
			time_stuck_in_loop = 0

			-- time to wait
			while ns.long_DRX and limiter:get_tsc_cycles() < last_activity + long_DRX_cycle_length_tsc_hz_ms - active_time_tsc_hz_ms do
				lcount = pipe:countPktsizedRing(ring.ring)
				if (lcount > 0) and (packet_arrival_time == 0) then
					packet_arrival_time = limiter:get_tsc_cycles()
				end
				if not mg.running() then
					return
				end
			end

			-- save the time the packet waited
			last_activity = limiter:get_tsc_cycles()
			if (lcount > 0) then
				time_stuck_in_loop = (last_activity-packet_arrival_time)
			end

			-- T_on is active
			while ns.long_DRX and limiter:get_tsc_cycles() < last_activity + active_time_tsc_hz_ms do
				if not mg.running() then
					return
				end

				count = pipe:countPktsizedRing(ring.ring)

				if count > 0 then
					print("long_DRX deactivating "..threadNumber)
					ns.long_DRX = false

					print("continuous_reception activating "..threadNumber)
					ns.continuous_reception = true

					last_activity = limiter:get_tsc_cycles()
					ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())

					break
				end
			end

			-- if the the max of interactive Time from long DRX arrived, return to RCC_IDLE
			if limiter:get_tsc_cycles() > ns.last_packet_time + inactive_long_DRX_cycle_time then

				print("long_DRX deactivating after inactive time, "..threadNumber)
				ns.long_DRX = false

				print("rcc_idle activating after inactive time, "..threadNumber)
				ns.rcc_idle = true
			end
		end

        -- if the RCC_IDLE mode is active
        if ns.rcc_idle then
            last_activity = limiter:get_tsc_cycles()

            local packet_arrival_time = 0
            local lcount = 0
            time_stuck_in_loop = 0

            -- time to wait
            while limiter:get_tsc_cycles() < last_activity + rcc_idle_cycle_length_tsc_hz_ms - active_time_tsc_hz_ms do
                lcount = pipe:countPktsizedRing(ring.ring)
                if (lcount > 0) and (packet_arrival_time == 0) then
                    packet_arrival_time = limiter:get_tsc_cycles()
                end
                if not mg.running() then
                    return
                end
            end

            -- save the time the packet waited
            last_activity = limiter:get_tsc_cycles()
            if (lcount > 0) then
                time_stuck_in_loop = (last_activity - packet_arrival_time)
            end

            -- T_on is active
            while limiter:get_tsc_cycles() < last_activity + active_time_tsc_hz_ms do
                if not mg.running() then
                    return
                end
                count = pipe:countPktsizedRing(ring.ring)

                if count > 0 then

                    print("rcc_idle deactivating "..threadNumber)
                    ns.rcc_idle = false

                    print("continuous_reception activating "..threadNumber)
                    ns.continuous_reception = true

                    ns.first_rcc_connected = true

                    ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())

                    break
                end
            end
        end

	end
end

-- Help function:
-- cast a uint64_i to "lua number"
function ullToNumber(value)

	local vstring = tostring(value)
	-- remove the "ULL" ending
	vstring = string.sub(vstring, 0, string.len(vstring) - 3)

	return tonumber(vstring)
end
