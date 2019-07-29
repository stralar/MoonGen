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

	-- start the forwarding tasks
	for i = 1, args.threads do
		mg.startTask("forward", ring1, args.dev[1]:getTxQueue(i - 1), args.dev[1], args.rate[1], args.latency[1], args.xlatency[1], args.loss[1], args.concealedloss[1], args.catchuprate[1])
		if args.dev[1] ~= args.dev[2] then
			mg.startTask("forward", ring2, args.dev[2]:getTxQueue(i - 1), args.dev[2], args.rate[2], args.latency[2], args.xlatency[2], args.loss[2], args.concealedloss[2], args.catchuprate[2])
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

    local tsc_hz = libmoon:getCyclesFrequency()

	-- DRX in LTE is in RRC_IDLE or in RRC_CONNECTED mode
	-- RRC_IDLE: sleep state
	-- RRC_CONNECTED:
	local rcc_idle = true

	-- the RRC_CONNECTED mode got the short DRX cycle and long DRX cycle
	local short_DRX = true

	local last_monitoring = limiter:get_tsc_cycles()
	local last_active = limiter:get_tsc_cycles()
	-- between 0.32 and 2.56 sec
	local rcc_idle_cycle_length = 2 * tsc_hz

	local short_DRX_cycle_length = 0.3 * tsc_hz
	local long_DRX_cycle_length = 0.6 * tsc_hz

	local active_time = 0.1 * tsc_hz

	local short_DRX_inactive = true
	local max_inactive_short_DRX_cycle = 20

	local long_DRX_inactive = true
	local max_inactive_long_DRX_cycle = 20


	local bufs = memory.createBufArray()
	local count = 0
	local count_hist = histogram:new()
	local ringsize_hist = histogram:new()
	local ringbytes_hist = histogram:new()
	while mg.running() do

		if not rcc_idle and limiter:get_tsc_cycles() > max_inactive_short_DRX_cycle * short_DRX_cycle_length + last_active then
			short_DRX = false
			print("short DRX deactivate")
		elseif not short_DRX and limiter:get_tsc_cycles() > max_inactive_long_DRX_cycle * long_DRX_cycle_length + max_inactive_short_DRX_cycle * short_DRX_cycle_length + last_active then
			rcc_idle = true
			short_DRX = true
			print("long DRX deactivate")
			print("rcc_idle activated")
		end
		-- if the RCC_IDLE mode is active and when the interval T_on is active
		if rcc_idle then

			-- T_on is active
			while limiter:get_tsc_cycles() < last_monitoring + active_time do
				if not mg.running() then
					return
				end
				count = rxQueue:recv(bufs)
				count_hist:update(count)
				--print("receive thread count="..count)
				for iix=1,count do
					local buf = bufs[iix]
					local ts = limiter:get_tsc_cycles()
					buf.udata64 = ts
				end
				if count > 0 then
					print("RCC_IDLE will be deactivate")
					rcc_idle = false
					last_active = limiter:get_tsc_cycles()

				    pipe:sendToPktsizedRing(ring.ring, bufs, count)
				    --print("ring count: ",pipe:countPacketRing(ring.ring))
				    ringsize_hist:update(pipe:countPktsizedRing(ring.ring))
				end
			end

			-- time to wait and in this time all packages will be droped
			while limiter:get_tsc_cycles() < last_monitoring + rcc_idle_cycle_length do
				if not mg.running() then
					return
				end
				rxQueue:recv(bufs)
			end
			last_monitoring = limiter:get_tsc_cycles()

		-- if RCC_CONNECTED mode is active
		elseif not rcc_idle then

			-- if the T_on interval is active
			if short_DRX then

				short_DRX_inactive = true
				-- T_on is active
				while limiter:get_tsc_cycles() < last_monitoring + active_time do
					if not mg.running() then
						return
					end
					count = rxQueue:recv(bufs)
					count_hist:update(count)
					--print("receive thread count="..count)
					for iix=1,count do
						local buf = bufs[iix]
						local ts = limiter:get_tsc_cycles()
						buf.udata64 = ts
					end
					if count > 0 then
						print("short DRX active")
						last_active = limiter:get_tsc_cycles()

						pipe:sendToPktsizedRing(ring.ring, bufs, count)
						--print("ring count: ",pipe:countPacketRing(ring.ring))
						ringsize_hist:update(pipe:countPktsizedRing(ring.ring))

					end
				end

				-- time to wait and in this time all packages will be droped
				while limiter:get_tsc_cycles() < last_monitoring + short_DRX_cycle_length do
					if not mg.running() then
						return
					end
					rxQueue:recv(bufs)
				end
				last_monitoring = limiter:get_tsc_cycles()

			-- if the T_on interval is active
			elseif not short_DRX then

				long_DRX_inactive = true

				-- T_on is active
				while limiter:get_tsc_cycles() < last_monitoring + active_time do
					if not mg.running() then
						return
					end
					count = rxQueue:recv(bufs)
					count_hist:update(count)
					--print("receive thread count="..count)
					for iix=1,count do
						local buf = bufs[iix]
						local ts = limiter:get_tsc_cycles()
						buf.udata64 = ts
					end
					if count > 0 then
						print("long DRX active")
						last_active = limiter:get_tsc_cycles()

						pipe:sendToPktsizedRing(ring.ring, bufs, count)
						--print("ring count: ",pipe:countPacketRing(ring.ring))
						ringsize_hist:update(pipe:countPktsizedRing(ring.ring))
					end
				end

				-- time to wait and in this time all packages will be droped
				while limiter:get_tsc_cycles() < last_monitoring + short_DRX_cycle_length do
					if not mg.running() then
						return
					end
					rxQueue:recv(bufs)
				end
				last_monitoring = limiter:get_tsc_cycles()
			end
		end
	end
	count_hist:print()
	count_hist:save("rxq-pkt-count-distribution-histogram-"..rxDev["id"]..".csv")
	ringsize_hist:print()
	ringsize_hist:save("rxq-ringsize-distribution-histogram-"..rxDev["id"]..".csv")
	end

function forward(ring, txQueue, txDev, rate, latency, xlatency, lossrate, clossrate, catchuprate)
	print("forward with rate "..rate.." and latency "..latency.." and loss rate "..lossrate.." and clossrate "..clossrate.." and catchuprate "..catchuprate)
	local numThreads = 1
	
	local linkspeed = txDev:getLinkStatus().speed
	print("linkspeed = "..linkspeed)

	local tsc_hz = libmoon:getCyclesFrequency()
	local tsc_hz_ms = tsc_hz / 1000
	print("tsc_hz = "..tsc_hz)

	-- larger batch size is useful when sending it through a rate limiter
	local bufs = memory.createBufArray()  --memory:bufArray()  --(128)
	local count = 0

	-- when there is a concealed loss, the backed-up packets can
	-- catch-up at line rate
	local catchup_mode = false

	-- DRX in LTE is in RRC_IDLE or in RRC_CONNECTED mode
	-- RRC_IDLE:
	local rcc_idle = true


	while mg.running() do
		-- receive one or more packets from the queue
		--local count = rxQueue:recv(bufs)
		--print("calling pipe:recvFromPktsizedRing(ring.ring, bufs)")
		count = pipe:recvFromPktsizedRing(ring.ring, bufs, 1)
		--print("call returned.")
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
			local closses = 0
			while (math.random() < clossrate) do
				closses = closses + 1
				if (catchuprate > 0) then
					catchup_mode = true
					--print "entering catchup mode!"
				end
			end
			local send_time = arrival_timestamp + (((closses+1)*latency + extraDelay) * tsc_hz_ms)
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

		--print("count="..tostring(count))

		--if count > 0 then
		if count > 0 then
			-- the rate here doesn't affect the result afaict.  It's just to help decide the size of the bad pkts
			txQueue:sendWithDelayLoss(bufs, rate * numThreads, lossrate, count)
			--print("sendWithDelay() returned")
		end
	end
end








