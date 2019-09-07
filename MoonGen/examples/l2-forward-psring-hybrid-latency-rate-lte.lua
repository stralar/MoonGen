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


	-- start the forwarding tasks
	for i = 1, args.threads do
		mg.startTask("forward", 1, ns, ring1, args.dev[1]:getTxQueue(i - 1), args.dev[1], args.rate[1], args.latency[1], args.xlatency[1], args.loss[1], args.concealedloss[1], args.catchuprate[1])
		if args.dev[1] ~= args.dev[2] then
			mg.startTask("forward", 2, ns, ring2, args.dev[2]:getTxQueue(i - 1), args.dev[2], args.rate[2], args.latency[2], args.xlatency[2], args.loss[2], args.concealedloss[2], args.catchuprate[2])
		end
	end

	-- start the receiving/latency tasks
	for i = 1, args.threads do
		mg.startTask("receive", ring1, args.dev[2]:getRxQueue(i - 1), args.dev[2])
		if args.dev[1] ~= args.dev[2] then
			mg.startTask("receive", ring2, args.dev[1]:getRxQueue(i - 1), args.dev[1])
		end
	end

	mg.waitForTasks()
end


function receive(ring, rxQueue, rxDev)
	--print("receive thread...")

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
		-- A little random delay, for the ping Test
		local ts = limiter:get_tsc_cycles()
		while limiter:get_tsc_cycles() < ts + (math.random()) do
			if not mg.running() then
				return
			end
		end

		if count > 0 then
				pipe:sendToPktsizedRing(ring.ring, bufs, count)
				--print("ring count: ",pipe:countPacketRing(ring.ring))
				ringsize_hist:update(pipe:countPktsizedRing(ring.ring))
			end
		end
		count_hist:print()
		count_hist:save("rxq-pkt-count-distribution-histogram-"..rxDev["id"]..".csv")
		ringsize_hist:print()
		ringsize_hist:save("rxq-ringsize-distribution-histogram-"..rxDev["id"]..".csv")
end

function forward(threadNumber, ns, ring, txQueue, txDev, rate, latency, xlatency, lossrate, clossrate, catchuprate)
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
	ns.short_DRX = true
	ns.continuous_reception = false
	ns.inactive_short_DRX_cycle = {0, 0}
	ns.inactive_long_DRX_cycle = {0, 0}

	ns.first_rcc_connected = false

	-- ns.last_activity = limiter:get_tsc_cycles() / 2

	local debug = false


	-- larger batch size is useful when sending it through a rate limi ter
	local bufs = memory.createBufArray()  --memory:bufArray()  --(128)
	local count = 0


	-- when there is a concealed loss, the backed-up packets can
	-- catch-up at line rate
	local catchup_mode = false

	local last_activity = limiter:get_tsc_cycles()

	-- between 0.32 and 2.56 sec
	local rcc_idle_cycle_length = 0.1 * tsc_hz

	local short_DRX_cycle_length = 0.015 * tsc_hz
	local long_DRX_cycle_length = 0.02 * tsc_hz

	local active_time = 0.005 * tsc_hz

	local max_inactive_short_DRX_cycle = 140

	local max_inactive_long_DRX_cycle = 400

	-- will be reset after each send/received package
	-- timer is between 1ms - 2.56sec Paper-[10]
	local continuous_reception_inactivity_timer = 0.2 * tsc_hz

	-- 16 to 19 signalling messages
	local rcc_connection_build_delay = 0.05 * tsc_hz

	-- in ms
	local concealed_resend_time = 8

	while mg.running() do

		-- RCC_IDLE to RCC_CONNECTED the delay
		if ns.first_rcc_connected then
			print("Build RCC_CONNECTION")
			last_activity = limiter:get_tsc_cycles()
			while limiter:get_tsc_cycles() < last_activity + rcc_connection_build_delay do
				if not mg.running() then
					return
				end
				-- if the other thread finished the LOOP
				if not ns.first_rcc_connected then
					break
				end
			end
			ns.first_rcc_connected = false
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
				-- TODO compare the timestamp if its lower than the give latency add some latency, so we can manage different MBit rates
				-- TODO because by higher rates a Latency will be create automatly because they are stuck in the Queue
				local send_time = arrival_timestamp
				if (closses > 0) then
					send_time = send_time + (((closses+1)*concealed_resend_time + latency + extraDelay) * tsc_hz_ms)
				else
					send_time = send_time + ((latency + extraDelay) * tsc_hz_ms)
				end

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
				--print("sendWithDelay() returned")
				-- last_activity = limiter:get_tsc_cycles()
                last_activity = limiter:get_tsc_cycles()

			end

			if limiter:get_tsc_cycles() > last_activity + continuous_reception_inactivity_timer then

				print("short_DRX activating "..threadNumber)
				ns.short_DRX = true

				print("continuous_reception deactivating "..threadNumber)
				ns.continuous_reception = false
			end

			--DEBUG
			if not ns.continuous_reception and ns.short_DRX and debug then
				print("short_DRX activate "..threadNumber)
				print("continuous_reception deactivate "..threadNumber)
			end

		-- if the RCC_IDLE mode is active
		elseif ns.rcc_idle then
			last_activity = limiter:get_tsc_cycles()
	
			-- time to wait
			while limiter:get_tsc_cycles() < last_activity + rcc_idle_cycle_length - active_time do
				if not mg.running() then
					return
				end
			end

			-- T_on is active
			while limiter:get_tsc_cycles() < last_activity + rcc_idle_cycle_length do
				if not mg.running() then
					return
				end
				-- count = pipe:recvFromPktsizedRing(ring.ring, bufs, 1)
				count = pipe:countPktsizedRing(ring.ring)

				if count > 0 then


					print("continuous_reception activating "..threadNumber)
					ns.continuous_reception = true

					print("rcc_idle deactivating "..threadNumber)
					ns.rcc_idle = false

					ns.first_rcc_connected = true
				end

				if ns.continuous_reception then
					break
				end
			end




			-- DEBUG
			if not ns.rcc_idle and ns.continuous_reception and debug then
				print("rcc_idle deactivate "..threadNumber)
				print("continuous_reception activate "..threadNumber)
			end

		-- if RCC_CONNECTED mode is active
		else
			if ns.short_DRX  then
				last_activity = limiter:get_tsc_cycles()

				-- time to wait
				-- TODO maybe need to add pipe:recvFromPktsizedRing(ring.ring, bufs, 1) for drop the packages
				while limiter:get_tsc_cycles() < last_activity + short_DRX_cycle_length - active_time do
					if not mg.running() then
						return
					end
				end

				-- T_on is active
				while limiter:get_tsc_cycles() < last_activity + short_DRX_cycle_length do
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

					end
					if ns.continuous_reception then
						ns.inactive_short_DRX_cycle = {0, 0}
						break
					end
				end

				if not ns.continuous_reception and threadNumber == 1 then
					ns.inactive_short_DRX_cycle =  {ns.inactive_short_DRX_cycle[1] + 1, ns.inactive_short_DRX_cycle[2]}
				end
				if not ns.continuous_reception and threadNumber == 2 then
					ns.inactive_short_DRX_cycle =  {ns.inactive_short_DRX_cycle[1], ns.inactive_short_DRX_cycle[2] + 1}
				end



				-- if the the max of interactive Time from short DRX arrived, it will be changed to long DRX
				if ns.inactive_short_DRX_cycle[threadNumber] == max_inactive_short_DRX_cycle then
					print("short_DRX deactivating after inactive time, "..threadNumber)
					ns.inactive_short_DRX_cycle = {0, 0}

					ns.short_DRX = false

					print("long_DRX activating after inactive time, "..threadNumber)
				end

				-- DEBUG
				if not ns.short_DRX and ns.continuous_reception and debug then
					print("short_DRX deactivate "..threadNumber)
					print("continuous_reception activate "..threadNumber)
				end

			else
				last_activity = limiter:get_tsc_cycles()

				-- time to wait
				while not ns.continuous_reception and limiter:get_tsc_cycles() < last_activity + long_DRX_cycle_length - active_time do
					if not mg.running() then
						return
					end
				end

				-- T_on is active
				while limiter:get_tsc_cycles() < last_activity + long_DRX_cycle_length do
					if not mg.running() then
						return
					end
					-- count = pipe:recvFromPktsizedRing(ring.ring, bufs, 1)
					count = pipe:countPktsizedRing(ring.ring)

					if count > 0 then
						print("long_DRX deactivating "..threadNumber)
						ns.short_DRX = true

						print("continuous_reception activating "..threadNumber)
						ns.continuous_reception = true

					end
					if ns.continuous_reception then
						ns.inactive_long_DRX_cycle = {0, 0}
						break
					end
				end

				if not ns.continuous_reception and threadNumber == 1 then
					ns.inactive_long_DRX_cycle =  {ns.inactive_long_DRX_cycle[1] + 1, ns.inactive_long_DRX_cycle[2]}
				end
				if not ns.continuous_reception and threadNumber == 2 then
					ns.inactive_long_DRX_cycle =  {ns.inactive_long_DRX_cycle[1], ns.inactive_long_DRX_cycle[2] + 1}
				end



				-- if the the max of interactive Time from long DRX arrived, return to RCC_IDLE
				-- TODO maybe need to add pipe:recvFromPktsizedRing(ring.ring, bufs, 1) for drop the packages
				if ns.inactive_long_DRX_cycle[threadNumber] == max_inactive_long_DRX_cycle then
					print("long_DRX deactivating after inactive time, "..threadNumber)
					ns.inactive_long_DRX_cycle = {0, 0}
					ns.short_DRX = true

					print("rcc_idle activating after inactive time, "..threadNumber)
					ns.rcc_idle = true
				end

				-- DEBUG
				if not ns.short_DRX and ns.continuous_reception and debug then
					print("long_DRX deactivate "..threadNumber)
					print("continuous_reception activate "..threadNumber)
				end
				-- DEBUG
				if not ns.short_DRX and  ns.rcc_idle and debug then
					print("long_DRX deactivate "..threadNumber)
					print("rcc_idle activate "..threadNumber)
				end
			end
		end
	end
end






