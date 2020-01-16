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


local turbo = require("turbo")
local tcpserver = require("turbo.tcpserver")
local ioloop = require('turbo.ioloop')
--local jsons = require("cjson.safe")
local json = require("turbo.3rdparty.JSON")


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

	ns.short_DRX_cycle_length = args.short_DRX_cycle_length
	ns.long_DRX_cycle_length = args.long_DRX_cycle_length
	ns.active_time = args.active_time
	ns.continuous_reception_inactivity_timer = args.continuous_reception_inactivity_timer
	ns.short_DRX_inactivity_timer =  args.short_DRX_inactivity_timer
	ns.long_DRX_inactivity_timer = args.long_DRX_inactivity_timer
	ns.rcc_idle_cycle_length = args.rcc_idle_cycle_length
	ns.rcc_connection_build_delay = args.rcc_connection_build_delay

	ns.thread = {{rate = args.rate[1], latency = args.latency[1],  xlatency = args.xlatency[1],  lossrate = args.loss[1],  clossrate = args.concealedloss[1],  catchuprate = args.catchuprate[1]},
				 {rate = args.rate[2], latency = args.latency[2],  xlatency = args.xlatency[2],  lossrate = args.loss[2],  clossrate = args.concealedloss[2],  catchuprate = args.catchuprate[2]}}


	-- start the forwarding tasks
	for i = 1, args.threads do
		

		mg.startTask("forward", 1, ns, ring1, args.dev[1]:getTxQueue(i - 1), args.dev[1], ns.thread[1].rate, ns.thread[1].latency, args.xlatency[1], args.loss[1], args.concealedloss[1], args.catchuprate[1],
			args.short_DRX_cycle_length, args.long_DRX_cycle_length, args.active_time, args.continuous_reception_inactivity_timer, args.short_DRX_inactivity_timer, args.long_DRX_inactivity_timer, args.rcc_idle_cycle_length, args.rcc_connection_build_delay)
			if args.dev[1] ~= args.dev[2] then
			mg.startTask("forward", 2, ns, ring2, args.dev[2]:getTxQueue(i - 1), args.dev[2], args.rate[2], args.latency[2], args.xlatency[2], args.loss[2], args.concealedloss[2], args.catchuprate[2],
					args.short_DRX_cycle_length, args.long_DRX_cycle_length, args.active_time, args.continuous_reception_inactivity_timer, args.short_DRX_inactivity_timer, args.long_DRX_inactivity_timer, args.rcc_idle_cycle_length, args.rcc_connection_build_delay)

		end
	end

	-- start the receiving/latency tasks
	for i = 1, args.threads do
		mg.startTask("receive", ring1, args.dev[2]:getRxQueue(i - 1), args.dev[2])
		if args.dev[1] ~= args.dev[2] then
			mg.startTask("receive", ring2, args.dev[1]:getRxQueue(i - 1), args.dev[1])
		end
	end
	
	--start the server thread
	mg.startTask("server", ns)


	mg.waitForTasks()
end


function receive(ring, rxQueue, rxDev)
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
			local buf = bufs[iix]
			local ts = limiter:get_tsc_cycles()
			buf.udata64 = ts
		end

		if count > 0 then
			pipe:sendToPktsizedRing(ring.ring, bufs, count)
			-- print("received")
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
	print("forward with rate "..ns.thread[threadNumber].rate.." and latency "..ns.thread[threadNumber].latency.." and loss rate "..ns.thread[threadNumber].lossrate.." and clossrate "..ns.thread[threadNumber].clossrate.." and catchuprate "..ns.thread[threadNumber].catchuprate)
	local numThreads = 1

	local linkspeed = txDev:getLinkStatus().speed
	print("linkspeed = "..linkspeed)

	local tsc_hz = libmoon:getCyclesFrequency()
	local tsc_hz_ms = tsc_hz / 1000
	print("tsc_hz = "..tsc_hz)

	print("Thread: "..threadNumber)

	local debug = false

	-- DRX in LTE is in RRC_IDLE or in RRC_CONNECTED mode
	-- RRC_IDLE: sleep state
	-- RRC_CONNECTED:
	ns.rcc_idle = true

	-- the RRC_CONNECTED mode got the short DRX cycle and long DRX cycle
	ns.short_DRX = false
	ns.long_DRX = false
	ns.continuous_reception = false

	local last_activity = limiter:get_tsc_cycles()

	ns.last_packet_time = ullToNumber(last_activity)

	ns.first_rcc_connected = false

	-- larger batch size is useful when sending it through a rate limiter
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

	local inactive_short_DRX_cycle_time = (short_DRX_inactivity_timer + continuous_reception_inactivity_timer) * tsc_hz_ms

	local inactive_long_DRX_cycle_time = (long_DRX_inactivity_timer + short_DRX_inactivity_timer + continuous_reception_inactivity_timer)* tsc_hz_ms

	-- 16 to 19 signalling messages
	local rcc_connection_build_delay_tsc_hz_ms = rcc_connection_build_delay * tsc_hz_ms

	-- in ms
	local concealed_resend_time = 8

	local time_stuck_in_loop = 0

	while mg.running() do
		-- RCC_IDLE to RCC_CONNECTED the delay
		if ns.first_rcc_connected then
			if debug then print("Build RCC_CONNECTION "..threadNumber) end
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
				if (ns.thread[threadNumber].xlatency > 0) then
					extraDelay = -math.log(math.random())*ns.thread[threadNumber].xlatency
				end

				-- emulate concealed losses
				local closses = 0.0
				while (math.random() < ns.thread[threadNumber].clossrate) do
					closses = closses + 1
					if (ns.thread[threadNumber].catchuprate > 0) then
						catchup_mode = true
						--print "entering catchup mode!"
					end
				end

				local send_time = arrival_timestamp
				--send_time = send_time + ((closses*concealed_resend_time + latency + extraDelay) * tsc_hz_ms + time_stuck_in_loop)
				if debug then print(ns.thread[threadNumber].latency) end
				send_time = send_time + ((closses*concealed_resend_time + ns.thread[threadNumber].latency + extraDelay) * tsc_hz_ms + time_stuck_in_loop)

				time_stuck_in_loop = 0

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
					buf:setDelay((pktSize) * (linkspeed/ns.thread[threadNumber].catchuprate - 1))
				else
					buf:setDelay((pktSize) * (linkspeed/ns.thread[threadNumber].rate - 1))
				end
			end

			if count > 0 then

				-- the rate here doesn't affect the result afaict.  It's just to help decide the size of the bad pkts
				txQueue:sendWithDelayLoss(bufs, ns.thread[threadNumber].rate * numThreads, ns.thread[threadNumber].lossrate, count)

				last_activity = limiter:get_tsc_cycles()
				ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())
			end
			if limiter:get_tsc_cycles() > last_activity + inactive_continuous_reception_cycle_time then
				if limiter:get_tsc_cycles() > ns.last_packet_time + inactive_continuous_reception_cycle_time then

					if debug then print("continuous_reception deactivating "..threadNumber) end
					ns.continuous_reception = false

					if debug then  print("short_DRX activating "..threadNumber) end
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
					if debug then  print("short_DRX deactivating "..threadNumber) end
					ns.short_DRX = false

					if debug then  print("continuous_reception activating "..threadNumber) end
					ns.continuous_reception = true

					last_activity = limiter:get_tsc_cycles()
					ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())

					break
				end
			end

			-- if the the max of interactive Time from short DRX arrived, it will be changed to long DRX
			if limiter:get_tsc_cycles() > ns.last_packet_time + inactive_short_DRX_cycle_time then
				if debug then  print("short_DRX deactivating after inactive time, "..threadNumber) end
				ns.short_DRX = false

				if debug then  print("long_DRX activating after inactive time, "..threadNumber) end
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
					if debug then  print("long_DRX deactivating "..threadNumber) end
					ns.long_DRX = false

						if debug then  print("continuous_reception activating "..threadNumber) end
					ns.continuous_reception = true

					last_activity = limiter:get_tsc_cycles()
					ns.last_packet_time = ullToNumber(limiter:get_tsc_cycles())

					break
				end
			end

			-- if the the max of interactive Time from long DRX arrived, return to RCC_IDLE
			if limiter:get_tsc_cycles() > ns.last_packet_time + inactive_long_DRX_cycle_time then

				if debug then print("long_DRX deactivating after inactive time, "..threadNumber) end
				ns.long_DRX = false

				if debug then  print("rcc_idle activating after inactive time, "..threadNumber) end
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

					if debug then print("rcc_idle deactivating "..threadNumber) end
                    ns.rcc_idle = false

					if debug then print("continuous_reception activating "..threadNumber) end
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


local function decode_wrapper(data)
	print("decode_wrapper")
	return json:decode(data)
end


function server(ns)
	print("Server Thread startet")

	local tsc_hz = libmoon:getCyclesFrequency()
	local tsc_hz_ms = tsc_hz / 1000
	

	while mg.running() do

		-- create IOLoop
		local ioloop_instance = ioloop.instance()

		-- create TCP server
		tcpserver.TCPServer:initialize(ioloop_instance, false)


		-- override handle stream from TCPServer
		function tcpserver.TCPServer:handle_stream(stream, address)
			print("connection builded:")

			local changed_data = {{rate = ns.thread[1].rate, latency = ns.thread[1].latency,  xlatency = ns.thread[1].xlatency,  lossrate = ns.thread[1].lossrate,  clossrate = ns.thread[1].clossrate,  catchuprate = ns.thread[1].catchuprate},
								  {rate = ns.thread[2].rate, latency = ns.thread[2].latency,  xlatency = ns.thread[2].xlatency,  lossrate = ns.thread[2].lossrate,  clossrate = ns.thread[2].clossrate,  catchuprate = ns.thread[2].catchuprate}}

			while not stream:closed() and mg.running() do

				if stream:closed() then
					print("stream closed")
					--ioloop_instance:close()
					self:stop()
				end
				if self._started and not stream:closed() then
					--print("out:")
					local buf, sz = stream:_read_from_socket()
					local data = ""
					if sz ~= nil then
						for i = 0, sz do
							--print(string.char(buf[i]))
							data = data..""..string.char(buf[i])
						end

						print("about to test for json")
						print(data)

						local result = pcall(decode_wrapper, data)
						if result then
							print("Is a json")
							local decoded_data = decode_wrapper(data)

							-- TODO error handler for wrong format

							-- set changes
							if decoded_data["short_DRX_cycle_length"] ~= nil then
								print("Set short cycle length: ")
								print(decoded_data["short_DRX_cycle_length"])
								ns.short_DRX_cycle_length = tonumber(decoded_data["short_DRX_cycle_length"])
							end
							if decoded_data["long_DRX_cycle_length"] ~= nil then
								print("Set : long_DRX_cycle_length")
								print(decoded_data["long_DRX_cycle_length"])
								ns.long_DRX_cycle_length = tonumber(decoded_data["long_DRX_cycle_length"])
							end
							if decoded_data["active_time"] ~= nil then
								print("Set : active_time")
								print(decoded_data["active_time"])
								ns.active_time = tonumber(decoded_data["active_time"])
							end
							if decoded_data["continuous_reception_inactivity_timer"] ~= nil then
								print("Set : continuous_reception_inactivity_timer")
								print(decoded_data["continuous_reception_inactivity_timer"])
								ns.ns.continuous_reception_inactivity_timer = tonumber(decoded_data["continuous_reception_inactivity_timer"])
							end
							if decoded_data["short_DRX_inactivity_timer"] ~= nil then
								print("Set : short_DRX_inactivity_timer")
								print(decoded_data["short_DRX_inactivity_timer"])
								ns.short_DRX_inactivity_timer = tonumber(decoded_data["short_DRX_inactivity_timer"])
							end
							if decoded_data["long_DRX_inactivity_timer"] ~= nil then
								print("Set : short_DRX_inactivity_timer")
								print(decoded_data["short_DRX_inactivity_timer"])
								ns.long_DRX_inactivity_timer = tonumber(decoded_data["long_DRX_inactivity_timer"])
							end
							if decoded_data["rcc_idle_cycle_length"] ~= nil then
								print("Set : rcc_idle_cycle_length")
								print(decoded_data["rcc_idle_cycle_length"])
								ns.rcc_idle_cycle_length = tonumber(decoded_data["rcc_idle_cycle_length"])
							end
							if decoded_data["rcc_connection_build_delay"] ~= nil then
								print("Set : rcc_connection_build_delay")
								print(decoded_data["rcc_connection_build_delay"])
								ns.rcc_connection_build_delay = tonumber(decoded_data["rcc_connection_build_delay"])
							end

							if decoded_data["thread1_rate"] ~= nil then
								print("Set : forwarding thread 1 rate")
								print(decoded_data["thread1_rate"])
								changed_data[1].rate = tonumber(decoded_data["thread1_rate"])
							end
							if decoded_data["thread1_latency"] ~= nil then
								print("Set : forwarding thread 1 latency")
								print(decoded_data["thread1_latency"])
								changed_data[1].latency = tonumber(decoded_data["thread1_latency"])
							end
							if decoded_data["thread1_xlatency"] ~= nil then
								print("Set : forwarding thread 1 xlatency")
								print(decoded_data["thread1_xlatency"])
								changed_data[1].xlatency = tonumber(decoded_data["thread1_xlatency"])
							end
							if decoded_data["thread1_queuedepth"] ~= nil then
								print("Set : forwarding thread 1 queuedepth")
								print(decoded_data["thread1_queuedepth"])
								changed_data[1].queuedepth = tonumber(decoded_data["thread1_queuedepth"])
							end
							if decoded_data["thread1_loss"] ~= nil then
								print("Set : forwarding thread 1 loss")
								print(decoded_data["thread1_loss"])
								changed_data[1].lossrate = tonumber(decoded_data["thread1_loss"])
							end
							if decoded_data["thread1_concealedloss"] ~= nil then
								print("Set : forwarding thread 1 concealedloss")
								print(decoded_data["thread1_concealedloss"])
								changed_data[1].clossrate = tonumber(decoded_data["thread1_concealedloss"])
							end
							if decoded_data["thread1_catchuprate"] ~= nil then
								print("Set : forwarding thread 1 catchuprate")
								print(decoded_data["thread1_catchuprate"])
								changed_data[1].catchuprate = tonumber(decoded_data["thread1_catchuprate"])
							end


							if decoded_data["thread2_rate"] ~= nil then
								print("Set : forwarding thread 1 rate")
								print(decoded_data["thread2_rate"])
								changed_data[2].rate = tonumber(decoded_data["thread2_rate"])
							end
							if decoded_data["thread2_latency"] ~= nil then
								print("Set : forwarding thread 2 latency")
								print(decoded_data["thread2_latency"])
								changed_data[2].latency = tonumber(decoded_data["thread2_latency"])
							end
							if decoded_data["thread2_xlatency"] ~= nil then
								print("Set : forwarding thread 2 xlatency")
								print(decoded_data["thread2_xlatency"])
								changed_data[2].xlatency = tonumber(decoded_data["thread2_xlatency"])
							end
							if decoded_data["thread2_queuedepth"] ~= nil then
								print("Set : forwarding thread 2 queuedepth")
								print(decoded_data["thread2_queuedepth"])
								changed_data[2].queuedepth = tonumber(decoded_data["thread2_queuedepth"])
							end
							if decoded_data["thread2_loss"] ~= nil then
								print("Set : forwarding thread 2 loss")
								print(decoded_data["thread2_loss"])
								changed_data[2].lossrate = tonumber(decoded_data["thread2_loss"])
							end
							if decoded_data["thread2_concealedloss"] ~= nil then
								print("Set : forwarding thread 2 concealedloss")
								print(decoded_data["thread2_concealedloss"])
								changed_data[2].clossrate = tonumber(decoded_data["thread2_concealedloss"])
							end
							if decoded_data["thread2_catchuprate"] ~= nil then
								print("Set : forwarding thread 2 catchuprate")
								print(decoded_data["thread2_catchuprate"])
								changed_data[2].catchuprate = tonumber(decoded_data["thread2_catchuprate"])
							end

							-- write changes to the namespace variable
							ns.thread = changed_data
						else
							print("Is not a json")
						end
					end
				end

				-- wait 1 second
				local last_timestamp = limiter:get_tsc_cycles()
				while limiter:get_tsc_cycles() < last_timestamp +  tsc_hz_ms * 100 do
					if not mg.running() then
						return
					end
				end
			end
			print("Connection lost")
		end

		-- tcp server listen on Port XXXX
		-- listen(port, address, backlog, family)
		tcpserver.TCPServer:listen(8888)

		-- start tcp server and ioloop
		tcpserver.TCPServer:start()
		ioloop_instance:start()
	end
end

