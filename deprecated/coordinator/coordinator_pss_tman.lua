require"splay.base"
rpc = require"splay.rpc"
misc = require "splay.misc"
crypto = require "crypto"

rpc.server(job.me.port)

-- #################### CLASS COORDINATOR ###################################
Coordinator={}
Coordinator.algos={}
--Coordinator.initAlgos=function(confObj)
-- For each algoId in confObj
--end

Coordinator.addProtocol=function(algo_id, algo_obj)
   
   local algo_seq = #Coordinator.algos+1
   
   algo_obj:setAlgoID(algo_id)   -- note: this method must be implemented by all protocols
--   log:print("COORDINATOR [addPROTOCOL] - at node: "..job.position.. " adding PROTOCOL seq: "..algo_seq.." id: "..algo_id.." table: "..tostring(algo_obj).." table set id:"..algo_obj:getAlgoID())
   local algo ={}
   algo.id=algo_id
   algo.obj=algo_obj
   Coordinator.algos[algo_seq]=algo

   
end


Coordinator.showProtocols=function()
    -- only for debud 
   log:print("#### Current added Protocols #######")
   for k,v in pairs(Coordinator.algos) do 
   	log:print(k, v.id, v.obj) 
   end
   log:print("####################################")
   
   
end


Coordinator.launch=function(running_time, delay)
	
	-- set termination thread
	events.thread(function() events.sleep(running_time) os.exit() end)
	-- TEST: init random number generator , removed for test: (initial view seems to be the same) 
	-- math.randomseed(job.position*os.time())
	local bootView=nil
	local desync_wait=nil
	-- test: wait for other nodes to start 
	events.sleep(10)
	
	-- init each added protocol	
	--for k,v in pairs(Coordinator.algos) do log:print(k, v.id, v.obj) end	
	for k, algo in pairs(Coordinator.algos) do
		log:print("COORDINATOR [launch] - ALGO CLASS: "..algo.obj:getProtocolClassName().." ALGO Seq: "..k.." ALGO ID: "..algo.id.." ALGO OBJ: "..tostring(algo.obj).." at node:"..job.position)
	  bootView=Coordinator.bootstrap(algo.obj:getViewSize())
	  algo.obj:init(bootView)
 	  desync_wait=(algo.obj:getCyclePeriod() * math.random())
    log:print("[Coordinator.launch()] at node: "..job.position.." desync_wait: "..desync_wait)
 	  events.sleep(desync_wait)
	  events.periodic(algo.obj:getCyclePeriod(), Coordinator.doActive)
	  log:print("[Coordinator.launch()] at node: "..job.position.." delay to next protocol: "..desync_wait)
    events.sleep(delay)
	end

end

Coordinator.doActive=function()
  
  local algo=nil
  for k, algo in pairs(Coordinator.algos) do
    --algo=Coordinator.algos[k]
    if algo.obj~=nil then
    	log:print("[Coordinator.doActive] - COORDINATOR ACTIVE THREAD at node: "..job.position.." for ALGO Seq: "..k.." ALGO id: "..algo.id.." ALGO OBJ: "..tostring(algo.obj))
    	algo.obj:active_thread()
    else
    	log:print("[Coordinator.doActive] - ALGO Seq: "..k.." is not instantiated")
    end
  end

end

Coordinator.send=function(algoId, dst, buf)

		local algo = nil
	  for k,v in pairs(Coordinator.algos) do 
   	    if v.id==algoId then
   	  		 algo = v.obj
   	    end
    end
		--local algo=Coordinator.algos[algoId]

	  log:print("Cycle / 2 "..algo.cycle_period)
		local ok, r = rpc.acall(dst.peer,{"Coordinator.passive_thread", algoId, job.position, buf}, algo.cycle_period/2)
		return ok, r
end

Coordinator.passive_thread=function(algoId, from, buffer)

		local algo = nil
	  for k,v in pairs(Coordinator.algos) do 
   	    if v.id==algoId then
   	  		 algo = v.obj
   	    end
    end
		--local algo=Coordinator.algos[algoId]
		
		log:print("[Coordinator.passive] - COORDINATOR PASSIVE THREAD at node: "..job.position.." received from sender id: "..from.." protocol: "..algoId)
		local ret = algo:passive_thread(from, buffer)
		--log:print("buffer size: "..#buffer)
		return ret
end


--Coordinator.bootstrap_algo=function(c, algoId)
--		local algo=Coordinator.algos[algoId]
--		log:print("[Coordinator.passive] - at node: "..job.position.." BOOTSTRAP protocol: ["..algoId.."]")
--		local ret = algo:bootstrap(c)
--		return ret
--end

Coordinator.bootstrap=function(c)
	local indexes = {}
	
	for i=1,#job.nodes do 
		indexes[#indexes+1]=i 
	end
	--remove myself
	table.remove(indexes,job.position) 
	
	local selected_indexes = misc.random_pick(indexes,math.min(c, #indexes))
	
	local result = ""
	for i=1,#selected_indexes do
		result = result..selected_indexes[i].." "	
	end
	log:print("[Coordinator.bootstrap] - BOOTSTRAP VIEW at node: "..job.position.." received (selected): ["..result.."]")
	
	return selected_indexes
end

------------------------ END OF CLASS COORDINATOR --------------------------

--#################### CLASS NODE ###################################
local Node = {}
Node.__index = Node 


function Node.new(me, id)

  local self = setmetatable({}, Node)
	
	self.peer=me
	self.id=id
	self.age=0
	self.payload={}  
	
  return self
end

function Node.setPeer(self, peer)
	self.peer = peer
end

function Node.getPeer(self)
	return self.peer
end

function Node.setID(self, id)
	self.id = id
end

function Node.getID(self)
	return self.id
end

function Node.setAge(self, age)
	self.age = id
end

function Node.getAge(self)
	return self.age
end

function Node.setPayload(self, payload)
  
  for k,v in pairs(payload) do
			self.payload[k] = v 
  end

end

function Node.getPayload(self)
	return self.payload
end

function Node.getPayloadSize(self)
	return #self.payload
end



------------------------ END OF CLASS NODES --------------------------



--#################### CLASS UTILITIES ###################################
--TODO organize utilities , some duplicate methods.

local Utilities={}
Utilities.__index=Utilities

function Utilities.new()
  local self=setmetatable({}, Utilities)
  return self
end


function Utilities.new(node)
  local self=setmetatable({}, Utilities)
  self.node = node 
  return self
end

function set_of_peers_to_string(v)

	  -- table.sort(v, function(a,b) return a.id < b.id end)

		local ret = ""
		for i=1,#v do
			if v[i] == nil then
				ret = ret.."NIL".." "	
			else
			  -- different options to print, used to debug
				-- view only with ids
				--ret = ret..v[i].id.." "
				-- view with id + age
				ret = ret..v[i].id.."("..v[i].age..") "	
				-- view with id + payload
				-- ret = ret..v[i].id.." "..get_payload_as_string(v[i])
				-- view with id + age + payload
				-- ret = ret..v[i].id.."("..v[i].age..") "..get_payload_as_string(v[i])
			end
			--ret = ret..v[i].id.." " --"#payload: "..#v[i].payload   --aqui
		end
		--log:print("VALUE: "..ret)
		return ret
end

function Utilities.print_this_view(self, message, view, cycle, algoId)
	--log:print("ALGO: "..algoId.." CYCLE: "..cycle)
  if message then 
    --log:print(message.." at node: ("..job.position..") id: "..me.id.." mypayload: "..get_payload_as_string(me).." cycle: "
    --  ..cycle.." view: "..set_of_peers_to_string(view))
    log:print("ALGO_ID:["..algoId.."] - "..message.." at node: "..self.node:getID().." id: "..self.node:getID().." cycle: "..cycle.." view(#"..#view.."): [ "..set_of_peers_to_string(view).."]")
  else
    log:print("ALGO_ID:["..algoId.."] VIEW at node: "..self.node:getID().." id: "..self.node:getID().." cycle: "..cycle.." view(# "..#view.." ): [ "..set_of_peers_to_string(view).."]")
  end
end

function Utilities.remove_dup(self, set)
		for i,v in ipairs(set) do
			local j = i+1
			while(j <= #set and #set > 0) do
				if v.id == set[j].id then
					table.remove(set,j)
				else j = j + 1
				end
			end
		end
end

function get_payload_as_string(peer)
    
    local mypayload = get_payload(peer)
		local res =""
		for i=1, #mypayload do
		     res = res..mypayload[i].." " 
		end
    return "["..res.."] "
end


function get_payload(peer)
	--TODO refactoring: send it to Utilities maybe
		local payl = {}
		if type(peer) == "table" then 
			payl = peer.payload 
		else 
			payl = peer 
		end
		return payl
	end



------------------------ END OF CLASS UTILITIES --------------------------

--#################### PSS UTILITIES ###################################
local PSS = {}
PSS.__index = PSS 

--function PSS.new(c, h, s, fanout,cyclePeriod, selection, me, algoId)
function PSS.new(c, h, s, fanout,cyclePeriod, selection, me)
  local self = setmetatable({}, PSS)
  self.cycle_numb=0
  self.view={}
  self.view_copy={}
  self.c=c
  self.H=h
  --self.S=s
  self.S=math.floor(self.c/2+0.5)-1
  self.exch=fanout
  --self.exch=math.floor(c/2+0.5)
  self.view_copy_lock=events.lock()
  self.cycle_period=cyclePeriod
  self.SEL=selection
  self.me=me
  self.utils=Utilities.new(me)
  self.ongoing_rpc= false
  self.is_init = false
  self.totalknown = 0
  --self.algoId = algoId
  self.algoId=nil
  self.logDebug = true
  -- auxiliary view , only used to check the convergence pf pss
  self.all_known_nodes={}
  self.protoName="PSS"
  
  return self
end
----------------------------------------------------
function PSS.getViewSize(self) return self.c end
function PSS.getCyclePeriod(self)  return self.cycle_period end
function PSS.getProtocolClassName(self) return self.protoName end
function PSS.setLog(self, flag) self.logDebug = flag end
function PSS.setAlgoID(self, algoId) self.algoId = algoId end
function PSS.getAlgoID(self) return self.algoId end
----------------------------------------------------
function PSS.pss_selectPartner(self)
		if #self.view > 0 then
			
			if self.SEL == "rand" then 
				return math.random(#self.view) 
			end
			
			if self.SEL == "tail" then
				local tail_ind = -1
				local biggerAge = -1
				
				for i,p in pairs(self.view) do
					if (p.age > biggerAge) then 
						biggerAge=p.age
						tail_ind = i
					end
				end
				assert (not (tail_ind == -1))
				return tail_ind
			end
			
			if self.SEL == "head" then
         local smallAge = 999
         local head_ind = -1
         for i, p in pairs(self.view) do
	         if p.age < smallAge then
	            smallAge = p.age
	            head_ind = i
	         end
	       end
         assert (not (head_ind == -1))
         return head_ind
      end
			
		else
			return false
		end
end

	----------------------------------------------------
--function PSS.same_peer_but_different_ages(self, a, b)	  
--  return a.peer.ip == b.peer.ip and a.peer.port == b.peer.port
--end

----------------------------------------------------
function PSS.same_peer(self,a,b)
  local condition=a.peer.ip == b.peer.ip and a.peer.port == b.peer.port
  return condition and a.age == b.age
end
----------------------------------------------------
function PSS.contains_id(t,id) 
  -- returns true and the key(position in the table) if id exists
  for k,v in pairs(t) do
    if v.id == id then 
      return true, k
    end 
  end
end

---------------------------------------------------i
function PSS.add_to_known_ids_set(self, node)
-- this function is used only for testing the convergence
 
-- if #self.all_known_nodes == 0 then 
--		self.all_known_nodes[1] = node.id
--		return
-- end

  for k,v in pairs(self.all_known_nodes) do
    if v == node.id then 
      return
    end 
  end
  
	self.all_known_nodes[#self.all_known_nodes+1] = node.id
 
end

------------------------------------------
function PSS.get_logged_known_ids(self)
	--print("received set size: "..#set)
	res = ""
	for k, v in ipairs(self.all_known_nodes) do
		res = res..tostring(v).." "
	 end
   return "[ "..res.." ]"
end

----------------------------------------------------
function PSS.pss_selectToSend(self, t_type)		
    -- check if the destination is not in the view 
	   
		local currentMethod = "[("..t_type..") - PSS.pss_SELECTTOSEND() ] - "
		if self.logDebug then 
	  	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." PSS.pss_SELECTTOSEND() - STARTED.")
	 	self.utils:print_this_view(currentMethod.."CURRENT PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)
		end
		local toSend = {}
		-- insert own descriptor to "toSend" buffer
		-- table.insert(toSend,{peer={ip=job.me.ip,port=job.me.port},age=0, id=me.id,payload=me.payload}) 
		table.insert(toSend, self.me) 
		if self.logDebug then
		self.utils:print_this_view(currentMethod.." add own descriptor to toSend buffer: ", toSend, self.cycle_numb, self.algoId)
		end
		
		if #self.view > 0 then 
		
			-- shuffle (permute) the view 
			self.view = misc.shuffle(self.view)
			if self.logDebug then
			self.utils:print_this_view(currentMethod.." SHUFFLE PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)
			end
			
			local tmp_view = misc.dup(self.view)
			if self.logDebug then
			self.utils:print_this_view(currentMethod.." COPIED PSS_VIEW to TEMP_VIEW: ", tmp_view, self.cycle_numb, self.algoId)
			end
			
			-- sort the view by age
			table.sort(tmp_view,function(a,b) return a.age < b.age end)
			if self.logDebug then
			self.utils:print_this_view(currentMethod.." TEMP_VIEW SORTED BY AGE: ", tmp_view, self.cycle_numb, self.algoId)
			end
			
			for i=(#tmp_view-self.H+1),#tmp_view do
				local ind = -1
				for j=1,#self.view do
					if self.same_peer(self, tmp_view[i],self.view[j]) then 
						ind=j; 
						break 
					end
				end
				assert (not (ind == -1))
				elem = table.remove(self.view,ind)  
				self.view[#self.view+1] = elem
			end
	
			for i=1,(self.exch-1) do
				toSend[#toSend+1]=self.view[i]
			end
		end
		
		if self.logDebug then
    	self.utils:print_this_view(currentMethod.." VIEW (buffer) SELECTED to be SENT:", toSend, self.cycle_numb, self.algoId)
    	self.utils:print_this_view(currentMethod.." PSS_VIEW after all SELECTTOSEND ", self.view, self.cycle_numb, self.algoId)	
    	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." PSS.pss_SELECTTOSEND() - END.")
    end
		return toSend
	end
----------------------------------------------------
	function PSS.pss_selectToKeep(self, received, t_type)
		
		-- logs	
	  local currentMethod = "[("..t_type..") -  PSS.pss_SELECTTOKEEP() ] - "
	  if self.logDebug then
	  	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." PSS.pss_SELECTTOKEEP() - STARTED.")
	  	self.utils:print_this_view(currentMethod.."CURRENT PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)
 	  	self.utils:print_this_view(currentMethod.."PSS: [received VIEW - buffer] at SELECTTOKEEP ", received, self.cycle_numb, self.algoId)
 	  end
 	  
		--merge received and local view
		for j=1,#received do
			self.view[#self.view+1] = received[j] 
		end
		if self.logDebug then
			self.utils:print_this_view(currentMethod.."PSS: after [merge VIEW + received VIEW] at SELECTTOKEEP ", self.view, self.cycle_numb, self.algoId)
		end
 	  
 	  -- ensures that the local node is node in the merged view.
		-- here is a possible problem, remove often (randomly) fails to remove the entry. checked by printing many before/after operation
		-- table.remove(self.view,self.me.id)
		-- try with this new funciion
		self.remove_all_instances_of_me(self.view, self.me.id)
		
		if self.logDebug then
    	self.utils:print_this_view(currentMethod.."PSS: merged VIEW after [removed instances of me] at SELECTTOKEEP ", self.view, self.cycle_numb, self.algoId)
		end
		
		-- remove duplicates: let only the newest node if there are duplicates. Remove older ones.
		local i = 1
		local condition=false
		while i < #self.view do  
		   -- NOTE: found another bug here. it was #self.view-1 before, it must be only #self.view
			for j=i+1,#self.view do
			  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." view size: "..#self.view.." i: "..i.." j: "..j)
					condition=self.view[i].peer.ip == self.view[j].peer.ip and self.view[i].peer.port == self.view[j].peer.port
				--if self.same_peer_but_different_ages(self.view[i], self.view[j]) then
				if condition then
				
					if self.logDebug then
						log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." EQUAL nodes found in the view, view#: "..#self.view.." i: "..i.." j: "..j)
     	  	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[i].id="..self.view[i].id)
     			  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[i].peer.ip="..self.view[i].peer.ip)
 	      	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[i].peer.port="..self.view[i].peer.port)
   	    	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[i].age="..self.view[i].age)
     
    	  	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[j].id="..self.view[j].id)
    	  	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[j].peer.ip="..self.view[j].peer.ip)
    	  	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[j].peer.port="..self.view[j].peer.port)
     	  	  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[j].age="..self.view[j].age)
     			  --log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." COMPARING AGES")
					end
				
					if self.view[i].age < self.view[j].age then 
						--log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[i].age < self.view[j].age ")
						table.remove(self.view,j) -- delete the oldest
				  else
				  	--log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.view[i].age > or = self.view[j].age ")
						table.remove(self.view,i)
				  end
					i = i - 1 
					break
				end
			end
			i = i + 1
		end
		if self.logDebug then
			self.utils:print_this_view(currentMethod.."[PSS: VIEW merged after [DUPLICATES - OLDER AGE] at SELECTTOKEEP:", self.view, self.cycle_numb, self.algoId)
		end
	  -- Correcting this block: BUG: if all nodes have the same age it also removes	
		-- remove old items from the view:  min(H,#view-c) 
--		local o = math.min(self.H,#self.view-self.c)
--		while o > 0 do
--			local oldest_index = -1
--			local oldest_age = -1
--			for i=1,#self.view do 
--				if oldest_age < self.view[i].age then
--					oldest_age = self.view[i].age
--					oldest_index = i
--				end
--			end
--			assert ((not (oldest_index == -1)), currentMethod.."[PSS - SELECTTOKEEP]: at node: "..job.position.." assert oldest_index == -1")
--			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." removing oldest node: "..self.view[oldest_index].id.."("..self.view[oldest_index].age..")")
--			table.remove(self.view,oldest_index)
--			o = o - 1
--		end
    -- using this block instead
		local o = math.min(self.H,#self.view-self.c)
		local diff = false
		if #self.view>1 then
			-- first checks if elements have different ages
			for i=1,#self.view-1 do
				if self.view[i].age ~= self.view[i+1].age then
		   		diff = true
				end
			end
			-- if so proceeds with the removal
			if diff then
					while o > 0 do
						local oldest_index = -1
						local oldest_age = 0  -- oldest age starts at 0 instead of -1
						for i=1,#self.view do 
							if oldest_age < self.view[i].age then
								oldest_age = self.view[i].age
								oldest_index = i
							end
						end
						if self.logDebug then
							log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." removing oldest node: "..self.view[oldest_index].id.."("..self.view[oldest_index].age..")")
						end
						table.remove(self.view,oldest_index)
						o = o - 1
					end
			else
			    if self.logDebug then
			   	  log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." NO NODES WITH DIFFERENT AGES WERE FOUND to remove the oldest nodes")
			   	end
			end
			
		end
		-- end correction.
		if self.logDebug then
   		self.utils:print_this_view(currentMethod.."[PSS: VIEW merged after [remove the min(H,#view-c) OLDEST ITEMS] at SELECTTOKEEP:", self.view, self.cycle_numb, self.algoId)
		end
		-- remove the head items from view: min(S,#view-c)
		o = math.min(self.S,#self.view-self.c)
		while o > 0 do
		  if self.logDebug then
		  	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." REMOVING HEAD node: "..self.view[1].id.."("..self.view[1].age..")")
 			end
			table.remove(self.view,1) -- not optimal
			o = o - 1
		end
		
		-- remove items at random: in the case there still are too many peers in the view 
		while #self.view > self.c do 
		  if self.logDebug then 
		  	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." PSS_VIEW size: "..#self.view)
		  end
		  local randnode_index = math.random(#self.view)
		  if self.logDebug then
		  	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." removing random node: "..self.view[randnode_index].id.."("..self.view[randnode_index].age..")")
		  end
			table.remove(self.view,randnode_index) 
		end

		assert (#self.view <= self.c, currentMethod.." at node: "..job.position.." #self.view <= self.c")
		
		if self.logDebug then
			self.utils:print_this_view(currentMethod.."PSS_VIEW after all SELECTTOKEEP:", self.view, self.cycle_numb, self.algoId)	
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." PSS.pss_SELECTTOKEEP() - END.")
		end
	end

----------------------------------------------------
	function PSS.pss_send_at_rpc(self,peer,pos,buf)
	  log:print("Cycle / 2 "..self.cycle_period)
		local ok, r = rpc.acall(peer,{"pss_passive_thread",pos, buf, self}, self.cycle_period/2)
		return ok, r
	end
-----------------------------------------------------
function PSS.remove_all_instances_of_me(view, id)
	-- removes all instances of an id from the view without calling other functions.
	-- everything is done in this function. 
  local found = true
  local index, value = 0
  
	 
	while(found) do
			found = false
	   	local index = 0
			for key,value in pairs(view) do
			 	--print("key: "..key.." id value: "..value.id)
		  		if value.id == id then 
			  	 	found = true
			  	 	index = key
						break
		      end 
		  end
		 if(index>0) then
	 			--print("value found at: "..index)	 		
				--print("current table size: "..#view) 	
				table.remove(view, index)
		 		--print("index removed")
		 		--print("table size now: "..#view)	
				--print_view(view)
			end
	end
end
----------------------------------------------------
	-- PSS PASSIVE THREAD
----------------------------------------------------

	function PSS.passive_thread(self, from, buffer)

		
		local currentMethod = "[PSS.PASSIVE_THREAD] - "
		if self.logDebug then
		  log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." invoked from: "..from.." [PSS.PASSIVE_THREAD] - STARTED")
		  self.utils:print_this_view(currentMethod.." CURRENT PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)
		end	
		-- check
		if self.ongoing_rpc or not self.is_init then
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." self.ongoing_rpc is true or pss.is_init is false: ignoring request invoked from: "..from.." [PSS.PASSIVE_THREAD] - END")
			return false
		end
	  
	  if self.logDebug then
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - size of received VIEW (buffer): "..#buffer)
			self.utils:print_this_view(currentMethod.." received VIEW (buffer) ", buffer, self.cycle_numb, self.algoId)
		end
		
		-- select to send		
		local ret = self.pss_selectToSend(self, "PASSIVE_THREAD")
		if self.logDebug then
			self.utils:print_this_view(currentMethod.." VIEW SELECTED TO RETURN (buffer): ", ret, self.cycle_numb, self.algoId)
		end
		
	  -- select to keep
		self.pss_selectToKeep(self,buffer, "PASSIVE_THREAD")
		

		-- increase the age of all nodes in the view
		for _,v in ipairs(self.view) do
				v.age = v.age+1
		end
		
		self.utils:print_this_view(currentMethod.." CURRENT PSS_VIEW after ALL PSS PASSIVE THREAD: ", self.view, self.cycle_numb, self.algoId)
		if self.logDebug then
			
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." [PSS.PASSIVE_THREAD] - END")
		end
		
		return ret
	end
----------------------------------------------------
	-- PSS ACTIVE THREAD
----------------------------------------------------
	
	function PSS.active_thread(self)		
	
  	local currentMethod = "[PSS.ACTIVE_THREAD] - "
  	if self.logDebug then
 	  	log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." [PSS.ACTIVE_THREAD] - STARTED")
			self.utils:print_this_view(currentMethod.."CURRENT PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)
		end
		
		-- used in the case of having 2 pss running at same time in order to avoid the coordinator to call 
		if not self.is_init then
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." PSS.IS_INIT is false: [PSS.ACTIVE_THREAD] - END")
			return false
		end
		

		self.ongoing_rpc=true

		--local exchange_aborted=true
		local retry = true
		local exchange_retry=3
			
		-- select a neighbour to send (part of) its view
		local partner_ind = self.pss_selectPartner(self)
		if not partner_ind then
				log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." : no partner selected (PSS_VIEW is empty?)")
				if self.logDebug then
					log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." [PSS.ACTIVE_THREAD] - END")
				end
				return
		end	
		local partner = self.view[partner_ind]
		
		if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." selected node to exchange: "..partner.id)
		end
		-- TEST/NOTE: again, if the node is removed from the view without knowing if the connection will be established and the exchanged done.
		-- This can reduce the view size and avoid the exchange with the selected node in the future. 
		-- Testing without removing: 
		-- table.remove(self.view,partner_ind)

	  -- select buffer to send: select view elements to send	
		local buffer = self.pss_selectToSend(self, "ACTIVE_THREAD")

		
		for i=1,exchange_retry do
    	if self.logDebug then
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." sending buffer to node: "..partner.id.." at try#: "..i)
			end
			local ok, r = Coordinator.send(self.algoId, partner, buffer)
			--local ok, r = self.pss_send_at_rpc(self,partner.peer,job.position, buffer) 

			if ok then
				if self.logDebug then
				log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." received - ok==true - from REMOTE node: "..partner.id)
				end
				local received = r[1]
				if received==false then
				  local w_delay = math.random()
				  if self.logDebug then
  				log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - received - false from REMOTE node: "..partner.id.." wating "..w_delay.." to retry again." )
  				end
					events.sleep(w_delay)	
					
				else
					--exchange_aborted=false 
					retry=false
					if self.logDebug then
					log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - received buffer from REMOTE node: "..partner.id.." invoking SELECTTOKEEP().")
					end
					self.pss_selectToKeep(self, received, "ACTIVE_THREAD")
	
					
				end
			else
				if self.logDebug then		
			  log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." received [ok==false] from REMOTE node: "..partner.id)
			  end
 			  log:warning(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - RPC error from PSS.passive_thread() function of REMOTE node: "..partner.id.." => ", r)
			  
				-- TEST: evaluate the behavoir without removing the node as done below, it will keep nodes with communincation errors in the view. 
				--       It will let the protocol to remove it by itself.
				-- table.remove(self.view,partner_ind)
			end		
			
			--if exchange_aborted==false then 
			if retry==false then
					if self.logDebug then
   				log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - retry==false : breaking the loop at retry#: "..i)
   				end
					break 
			end
			
		end
		
		-- sort view by id
		table.sort(self.view,function(a,b) return a.id < b.id end)
		
		-- make a copy of the current view: this copy is used by method getPeer() which is the method offered by the PSS API to other protocols to access the view. 
		-- e.g., getPeer is the method used by TMAN to get PSS' view
		self.view_copy_lock:lock()
		local viewCopyLock = misc.time()
		self.view_copy = misc.dup(self.view)
		self.view_copy_lock:unlock()

		
		if self.logDebug then
			log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - increasing the age of all nodes in PSS_VIEW")
		end
		-- increase the age of all nodes in the view
		for _,v in ipairs(self.view) do
				v.age = v.age+1
		end

	  -- debug: 	
	  if self.logDebug then
    	self.utils:print_this_view(currentMethod.."CURRENT PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)	
		end
		------------------------------------------------------------------------------------	
		-- CONVERGENCE: adds IDs of known nodes to a global set/table called all_known_nodes
		for _,v in pairs(self.view) do
		  self.add_to_known_ids_set(self, v)
		end
		
		--print view check information
		--if self.logDebug then
			log:print("[PSS.active_thread] - PSS_VIEW CONVERGENCE at node: "..job.position.." id: "..self.me.id.." cycle: "..self.cycle_numb.." all_known_nodes size: "..#self.all_known_nodes)
		--end
		------------------------------------------------------------------------------------
		
    -- print view	
    self.utils:print_this_view(currentMethod.."CURRENT PSS_VIEW: ", self.view, self.cycle_numb, self.algoId)	
	
		if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." [PSS.ACTIVE_THREAD] - END")
    end
    -- increase cycle number
		self.cycle_numb = self.cycle_numb+1
		-- allow incoming passive threads
		self.ongoing_rpc = false	

			
	end
	
----------------------------------------------------

	function PSS.getPeer(self)
		
		self.view_copy_lock:lock()
		local peer=nil
		if #self.view_copy ~= 0 then 
			if self.logDebug then
			log:print("[PSS.getPeer] - VIEW COPY SIZE: "..#self.view_copy)
			end
			peer = self.view_copy[math.random(#self.view_copy)] 
			if self.logDebug then
			log:print("[PSS.getPeer] - GET PEER RESU: "..peer.id)
			end
		else
			 if self.logDebug then
			 	log:print("[PSS.getPeer] - VIEW COPY ZERO: ")
			 end
		   peer = nil
		end
	
		self.view_copy_lock:unlock()
		
		return peer
		
	end
----------------------------------------------------
	
	function PSS.getViewCopy(self)
		
		
		return self.view_copy
		
	end
----------------------------------------------------
	function PSS.init(self, selected_indexes)
	
	local currentMethod = "[PSS.INIT] - STARTED"
	
		--for i=1,#selected_indexes do
		--	log:print("PSS INIT: at ("..job.position..") selected index: "..selected_indexes[i])
		--end	
		for i,v in pairs(selected_indexes) do
			  log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - setting selected index "..v.." to PSS_VIEW")
				local a_peer = job.nodes[v]
				--local hashed_index = compute_hash(tostring(a_peer.ip) ..":"..tostring(a_peer.port))
				local hashed_index = v
				
				--log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - invoking  self.getRemotePayload(..self..,.."..tostring(a_peer.ip)..")")
				--if(a_peer==nil) then
        -- log:print(currentMethod.." at node: "..job.position.." a_peer nill" )
    		--else
        -- log:print(currentMethod.." at node: "..job.position.." a_peer not nill" )
   			--end
				--local payload = self.getRemotePayload(self, a_peer)
		
		 		--self.view[#self.view+1] = {peer=a_peer,age=math.random(self.c),id=hashed_index , payload={}}  -- aqui added payload
		 		
		 		--self.view[#self.view+1] = {peer=a_peer,age=0,id=hashed_index , payload={}}  --
		 		-- now setting node objects to the view
		 		local newnode = Node.new(a_peer, hashed_index)
		 		self.view[#self.view+1] = newnode 
		 		
		end
		-- sort view by id
		table.sort(self.view,function(a,b) return a.id < b.id end)
		
		self.view_copy = misc.dup(self.view)
		assert (#self.view == math.min(self.c,#selected_indexes))
		
		self.utils:print_this_view("[PSS.INIT] - VIEW_INITIALIZED:", self.view, self.cycle_numb, self.algoId)
		self.is_init=true
		

	end
------------------------------------------------------------------------
function PSS.getRemotePayload(self, dst)

	  -- this method may be useless - check used to test the bootstrap but may be remove later.
    local currentMethod = "[PSS.INIT.GETREMOTEPAYLOAD] - "
    local received_payload = {}
    
    if(dst==nil) then
    else
         log:print(currentMethod.." at node: "..job.position.." DST NOT NILL" )
    end
    log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." trying to update data from node id: "..tostring(dst.ip)) 
                 
		local ok, r = rpc.acall(dst,{tostring(self.algoId..".getLocalPayload"), me})
		if ok then
				log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." received - ok==true - from REMOTE node: "..tostring(dst.ip))
			
				local received_pl = r[1]
				if received_pl==false then
  				log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - received_pl [false] from REMOTE node: "..tostring(dst.ip))
				else
					log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." - received_pl [payload buffer] from REMOTE node: "..tostring(dst.ip))
					received_payload = received_pl
				end
		else
			  log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." received [ok==false] from REMOTE node: "..tostring(dst.ip))	 
		end
		return received_payload
end	
------------------------------------------------------------------------
function PSS.getLocalPayload(self, from)
 	  -- this method may be useless - check used to test the bootstrap but may be remove later. 
    local currentMethod = "[PSS.GETPAYLOAD] - "
    log:print(currentMethod.." at node: "..job.position.." at cycle: "..self.cycle_numb.." invoked from: "..tostring(from.id))
		return self.me.payload
end
------------------------------------------------------------------------
function PSS.get_id(self)
  return self.me.id
end




------------------------ END OF CLASS PSS ----------------------------

-- #################### CLASS TMAN ###################################

local TMAN ={}
TMAN.__index = TMAN


--function TMAN.new(me, size, cycle_period, base_procotols, active_b_proto, algoId)
function TMAN.new(me, size, cycle_period, base_procotols, active_b_proto)
  local self = setmetatable({}, TMAN)

  self.utils=Utilities.new(me)
  self.t_view = {}  
	self.t_last_view = {}
	self.t_last_view_as_string = ""
	self.view_stable_info = false
	self.view_stable_counter = 0
	
	self.t_view_lock = events.lock()
	self.ongoing_rpc = false
	self.is_init = false
	self.cycle_numb = 0
	self.rank_func = nil
	self.rank_extra_params={}
	
  self.me=me	
	self.s = size
	self.cycle_period = cycle_period
	self.algos={}
	self.b_protocol = {}
	self.b_active = active_b_proto
 
  for i,v in pairs(base_procotols) do
		self.b_protocol[i] = v   
  end
  self.logDebug = true
  self.protoName="TMAN"
	--self.algoId = algoId
	self.algoId = nil
  return self
end
----------------------------------------------------

function TMAN.getViewSize(self) return self.s end

function TMAN.getCyclePeriod(self) return self.cycle_period end

function TMAN.getProtocolClassName(self) return self.protoName end

function TMAN.setLog(self, flag) 
	self.logDebug = flag 
end

function TMAN.setAlgoID(self, algoId)
	self.algoId = algoId
end

function TMAN.getAlgoID(self)
  return self.algoId
end
----------------------------------------------------

	function TMAN.select_peer(self) 
  	local currentMethod = "[TMAN.SELECT_PEER] - "
			
		--local ranked_view = self.rank_view(self, self.me, self.t_view)
		local ranked_view = self.rank_view(self)
		
		if (ranked_view and #ranked_view >0) then
		  if self.logDebug then
				log:print(currentMethod.." at node: "..job.position.." node selected: "..ranked_view[1].id)  	
		  end
			return ranked_view[1]
		else
			return false
		end
	end
----------------------------------------------------	
	

	function TMAN.init(self, view)

		local currentMethod = "[TMAN.INIT] - "
		if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." STARTED")
		end
		-- look for active algo 
		local active_algo_base = nil
		for k,v in pairs(self.b_protocol) do
		    --log:print(k,tostring(v))
				if v:getAlgoID()==self.b_active then
				   active_algo_base = v
				end
		end
		
		if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." active base protocol id: "..self.b_active.." is :"..tostring(active_algo_base))
		end
		--local active_algo_base = self.b_protocol[self.b_active]
		
		local peer = nil
		for i = 1, self.s do 
			peer = active_algo_base:getPeer()
			if peer ~= nil then
				self.t_view[i] = peer
				if self.logDebug then
					log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." getPeer() returned node: "..peer.id)
				end
				self.is_init = true	
			else
					if self.logDebug then
						log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." getPeer() returned node IS NULL")
					end
			end
		end
		
		if self.logDebug then
		self.utils:print_this_view("TMAN_VIEW INITIALIZED FROM_PSS:", self.t_view, self.cycle_numb, self.algoId)
		log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." END")
		end
		
	end
	
----------------------------------------------------
	function TMAN.select_view_to_send(self, selected_peer)
		local currentMethod = "[TMAN.SELECT_VIEW_TO_SEND] - "
		
	  -- look for active algo 
		local active_algo = nil
		for k,v in pairs(self.b_protocol) do
		    log:print(k,tostring(v))
		    log:print(v:getAlgoID())
				if v:getAlgoID()==self.b_active then
					 log:print("found: "..v:getAlgoID())
				   active_algo = v
				end
		end
		
		if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." active base protocol id: "..self.b_active.." is :"..tostring(active_algo))
		end
		--local active_algo = self.b_protocol[self.b_active]
	  
		-- make a copy of the PSS
		local buffer = active_algo:getViewCopy()
		-- merges tman and pss view
		local merged =  misc.merge(self.t_view, buffer)
		-- add myself to the merged buffer
		merged[#merged+1] = self.me
		-- remove duplicates and the destination from the buffer
		self.remove_dup(self,merged)
		-- remove destination from merged view
		log:print("selected peer received: "..selected_peer)
		self.remove_node(self,merged, selected_peer)
		
		return merged	
	end
	
----------------------------------------------------
	function TMAN.update_view_to_keep(self, received)
		
		self.t_view_lock:lock()
		self.t_view = misc.merge(received, self.t_view)

		self.remove_dup(self, self.t_view)
		self.t_view = self.rank_view(self)
		
		self.keep_first_n(self, self.s,self.t_view)
		-- keep view sorted by id after rank - useful for later checks
		table.sort(self.t_view,function(a,b) return a.id < b.id end)
		
		--self.check_view_stability(self)
		
		self.t_view_lock:unlock()
		
	end
----------------------------------------------------
	function TMAN.check_view_stability(self)
	
		local tmp_t_view = {}
		
		log:print("TMAN stable check")

		if #self.t_last_view == 0 then
			 log:print("TEST : last view is empty, #TMAN.t_last_view: "..#self.t_last_view)
			 self.t_last_view = self.t_view
			 
			 log:print("TEST : last view is empty, #TMAN.t_last_view: "..job.position.." : "..self.me.id.." #TMAN.t_last_view == 0 ")
		else

			if self.same_view(self, self.t_last_view, self.t_view)==true then
				 self.view_stable_counter = self.view_stable_counter +1
				 log:print("TEST :TMAN at ("..job.position..") "..self.me.id.." equal views")
				
				   
			else
				 log:print("TEST :TMAN at ("..job.position..") "..self.me.id.." NOT equal views ")
				
				 self.t_last_view = self.t_view
				 self.view_stable_counter = 0
				 self.view_stable_info=false
								 
			end
			log:print("TMAN TEST : counter at ("..job.position..") "..self.me.id.." is: "..self.view_stable_counter.." total cycles: "..self.cycle_numb)
		end
		--TODO change the stable condition here.
		if self.view_stable_counter>10 and self.view_stable_info==false then
			log:print("TEST VIEW stable true (>10 cycles) at node: "..job.position.." "..self.me.id.." after "..self.cycle_numb.." cycles")
			self.view_stable_info=true


		end	 
	end
----------------------------------------------------
	function TMAN.same_view(self, v1,v2)
		-- in this case v1 and v2 must be previously ordered by id
		--TODO refactoring: send it to Utilities
		if type(v1) == "table" and  type(v2) == "table" then
			if #v1 == #v2 then
			  for i=1,#v1 do
			    if v1[i].id ~= v2[i].id then
			    	return false
			    end
			  end
			  return true
			else
			  return false
			end
			
		end	
	end
	
----------------------------------------------------
	function TMAN.same_ids_view(self, v1,v2)
		--TODO refactoring: send it to Utilities
		if type(v1) ~= "table" then
		    return e1 == e2
		elseif type(v2) == "table" then

				for i=1,#v1 do
					local found = false
						for y=1,#v2 do
							if v1[i].id == v2[y].id then
							    found = true
							end
						end
						if found==false then
							return "false"
						end	
				end
			return "true"
		end	
	end
----------------------------------------------------
	function TMAN.same_id(self, n1,n2)
			--TODO refactoring: send it to Utilities
		local peer_first
		if n1.peer then 
			peer_first = n1.peer 
		else 
			peer_first = n1 
		end
		local peer_second
		if n2.peer then 
			peer_second = n2.peer 
		else 
			peer_second = n2 
		end
		return peer_first.id == peer_second.id 
	end
	
----------------------------------------------------
	function TMAN.keep_first_n(self, n, set)
	--TODO refactoring: send it to Utilities
		for i = #set, n+1, -1 do
			table.remove(set,i)
		end
	end
----------------------------------------------------
	function TMAN.set_distance_function(self, f)
		self.rank_func = f
	end
----------------------------------------------------
	function TMAN.set_distance_function(self, f, args)
	 	self.rank_extra_params = args
		self.rank_func = f
	end
	
----------------------------------------------------
	function TMAN.set_distFunc_extraParams(self, args)
	
	  if self==nil then
	    log:print("at node: "..job.position.." 3 self nill")
	  else
	   log:print("at node: "..job.position.." 3 self notl nill")
	    log:print("at node: "..job.position.." self "..tostring(self))
	  end
	  
	 	self.rank_extra_params = args
	  log:print("aux setting rank extra param: "..self.rank_extra_params[1])
	end
----------------------------------------------------
	function TMAN.get_distFunc_extraParams(self)
	
	  if self==nil then
	    log:print("at node: "..job.position.." 2 self nill")
	  else
	    log:print("at node: "..job.position.." 2 self notl nill:  "..tostring(self))

	  end
	 
	 
	  
	  if self.rank_extra_params==nil then
	    log:print("at node: "..job.position.." self .rank_extra_params nill")
	  else
	    log:print("at node: "..job.position.." self .rank_extra_params not nill self: "..tostring(self))
	  end
	   

	   for k,v in pairs(self.rank_extra_params) do
	       log:print("at node: "..job.position.." self  k,v : "..k..", "..v)
	   end
	   
	   
	 	return self.rank_extra_params 
	end
----------------------------------------------------
	function TMAN.dist_function(self, p1, p2)
	
	  if self==nil then
	    log:print("at node: "..job.position.." 7 self dist_function nil: ")
	  else
	   log:print("at node: "..job.position.." 7 self dist_function not nil: "..tostring(self))
	  end
		
		dist = self.rank_func(self, p1, p2)
		return dist
		
	end
----------------------------------------------------
	function TMAN.rank_view(self)
	
	  local currentMethod = "[TMAN.RANK_VIEW] - "
	  if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." STARTED")
		end
		
		local distances = {}
		local ranked = {}
		
		local mypayload = self.get_payload(self, self.me)
		local res =""
		for i=1, #mypayload do
		     res = res..mypayload[i]..", " 
		end
		
		if self.logDebug then
    log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." local payload ["..res.."]")
		end
		
		for i,v in ipairs(self.t_view) do
			
			local nb_payload =  self.get_payload(self, v)
			res = ""
			for i=1, #nb_payload do
					 res = res..nb_payload[i]..", "
			end
			
			if self.logDebug then
			log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." - neighbour "..v.id.." neighbour_payload ["..res.."]")
			end
			
				
			--local dist = self.dist_function(self, self.get_payload(self, self.me), self.get_payload(self, v))
			 if self==nil then
	     	log:print("at node: "..job.position.." 4 self dist_function nill: ")
	     else
	     	log:print("at node: "..job.position.." 4 self dist_function not nill: "..tostring(self))
	     end
	    
			local dist = self.dist_function(self, mypayload, nb_payload)
			
			if self.logDebug then
				log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." TMAN distance ("..self.me.id..","..v.id..") : "..dist)
			end
			distances[#distances+1] = {distance= dist, node=v}
			
		end
	
		table.sort(distances, function(a,b) return a.distance < b.distance end)
		
		local l_thread =""
		if self.ongoing_rpc then
			l_thread = "ACTIVE THREAD"
		else
			l_thread = "PASSIVE THREAD"
		end

		local	ret=""
		local cumul_distance=0
		
		for i,v in ipairs(distances) do
			if self.logDebug then
		  log:print(currentMethod.." "..l_thread.." at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." ranking["..i.."]: distance to "..v.node.id.." is "..v.distance)
			end
			ret = ret.." "..v.node.id.." : ["..v.distance.."] "	
			cumul_distance = cumul_distance+v.distance
		end
		
		if self.logDebug then
		log:print(currentMethod.." "..l_thread.." TMAN_VIEW ranking at node: "..job.position.." id : "..self.me.id.." cycle: "..self.cycle_numb.." avg dist: "..cumul_distance/#distances.." view - "..ret)
		end
	
		for i,v in ipairs(distances) do
			ranked[#ranked+1] = v.node
		end
		
		if self.logDebug then
		log:print(currentMethod.." at node: "..job.position.." id : "..self.me.id.." END")
		end
		return ranked

	end

----------------------------------------------------
	function TMAN.get_payload(self, node)
	--TODO refactoring: send it to Utilities maybe
		local payl = {}
		if type(node) == "table" then 
			payl = node.payload 
		else 
			payl = node 
		end
		return payl
	end

----------------------------------------------------
	function TMAN.remove_failed_node(self, node)

		self.t_view_lock:lock()
		self.remove_node(self, self.t_view, node)
		self.t_view_lock:unlock()
		
	end
----------------------------------------------------
	function TMAN.remove_node(self, t, node)
   	--log:print("remove node : "..node)
 
 		
			--TODO refactoring: send it to Utilities maybe	
		local j = 1
		for i = 1, #t do
		  
		  --log:print("t[j] node : "..t[j].id)
			--if self.same_node(self, t[j], node) then
			if  t[j].id==node then  
			  --log:print("same node")
				table.remove(t, j)
			else j = j+1 
			end
		end
		
	end

----------------------------------------------------
	function TMAN.same_node(self, n1,n2)
		--TODO refactoring: send it to Utilities maybe
		--log:print("n1. id: "..n1.id)
		--log:print("n2. peer: "..n2.id)
		
		local peer_first
		if n1.peer then 
			peer_first = n1.peer 
		else 
			peer_first = n1 
		end
		
		local peer_second
		if n2.peer then 
			peer_second = n2.peer 
			else 
			peer_second = n2 
		end
		
		return peer_first.port == peer_second.port and peer_first.ip == peer_second.ip
	end
	

----------------------------------------------------
	function TMAN.remove_dup(self, set)
		--TODO refactoring: send it to Utilities maybe	
		for i,v in ipairs(set) do
			local j = i+1
			while(j <= #set and #set > 0) do
				if v.id == set[j].id then
					table.remove(set,j)
				else j = j + 1
				end
			end
		end
		
	end

----------------------------------------------------

	
---------------------------------------------------- 
	function TMAN.active_thread(self)
		
		local currentMethod = "[TMAN.ACTIVE_THREAD] - "
		if self.logDebug then
		log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." [TMAN.ACTIVE_THREAD] - STARTED")
		self.utils:print_this_view(currentMethod.."CURRENT TMAN_VIEW:", self.t_view, self.cycle_numb, self.algoId)
		end
		
		self.ongoing_rpc=true

		-- for debug only
		mytopics = ""
		for i=1, #self.me.payload do
		   mytopics = mytopics..self.me.payload[i].." "
	  end
		
		if self.logDebug then
		log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." TMAN payload: [ "..mytopics.." ]")		
		end
		
		local selected_peer = self.select_peer(self) 

		if not selected_peer then 
		  if self.logDebug then
			log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." TMAN active_thread: no selected_peer selected") 
			end
			return 
		else
		   	log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." TMAN selected_peer: "..selected_peer.id)
		end
		
		local buffer = self.select_view_to_send(self, selected_peer.id)
	
		local try = 0
		local trials = 3 

		-- local status, reply = rpc.acall(selected_peer.peer, {'TMAN.t_passive_thread',buffer,me}) 
		
		local status, reply = Coordinator.send(self.algoId, selected_peer, buffer)
		
		-- TODO create a flag to actvate or deactivate the retry
		while not status do
			try = try + 1
			if try <= trials then 
			  retry_time = math.random(try * 3, try * 6)
			  if self.logDebug then
					log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." got no response from: "..selected_peer.id.. " - "..tostring(reply).." => trying again in "..retry_time.." seconds")
				end
				events.sleep(retry_time)
				
				-- status, reply = rpc.acall(selected_peer.peer,{'TMAN.t_passive_thread',buffer,me})
				status, reply = Coordinator.send(self.algoId, selected_peer, buffer)
				
			else
				if self.logDebug then
				log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." got no response from: "..selected_peer.id.. " - "..tostring(reply))
				end
				-- TODO check it: removing it in pss it was a problem, should I remove it?  probably not. review algo
				-- self.remove_failed_node(self, selected_peer)
				break
			end
		end	
		
		
		if status then
			
			local received = reply[1]
			if received==false then
					if self.logDebug then
					log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." TMAN didnt receive a reply from remote node: "..selected_peer.id)
					end
			else
	
			
			self.update_view_to_keep(self, received) 
				
			end
		end
	
		self.utils:print_this_view(currentMethod.."CURRENT TMAN_VIEW:", self.t_view, self.cycle_numb, self.algoId)
		self.cycle_numb = self.cycle_numb+1
		self.ongoing_rpc=false
		if self.logDebug then
		log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." [TMAN.ACTIVE_THREAD] - END")
		end
	end

----------------------------------------------------
	function TMAN.passive_thread(self, sender, received)
	
	local currentMethod = "[TMAN.PASSIVE_THREAD] - "
	log:print(currentMethod.." at node: "..self.me.id.." sender: "..sender)
	
	if self.logDebug then
		log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." [TMAN.PASSIVE_THREAD] - STARTED")
		self.utils:print_this_view(currentMethod.."CURRENT TMAN_VIEW:", self.t_view, self.cycle_numb, self.algoId)
	end
	
		if self.ongoing_rpc or not self.is_init then
			log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." [self.ongoing_rpc or not self.is_init]")
			return false
		end

		local buffer_to_send = self.select_view_to_send(self, sender)
		self.update_view_to_keep(self, received)
		
		
		self.utils:print_this_view(currentMethod.."CURRENT TMAN_VIEW:", self.t_view, self.cycle_numb, self.algoId)
		if self.logDebug then
			log:print(currentMethod.." at node: "..self.me.id.." at cycle: "..self.cycle_numb.." [TMAN.ACTIVE_THREAD] - END")
		end
		
		return buffer_to_send
	end
----------------------------------------------------
	function TMAN.set_node_representation(self, node_rep)
	
	  self.me.payload= node_rep
	  local pl_string = ""
		--for i=1, #node_rep do
		for i=1, #self.me.payload do
  	 	 -- self.me.payload[#self.me.payload+1] = node_rep[i]
			 pl_string = pl_string.." "..node_rep[i]
	 	end
	 	if self.logDebug then
	 		log:print("TMAN - At node: "..job.position.." id: "..self.me.id.." setting node representation (payload): [ "..pl_string.." ]")
	 	end
	end

	

------------------------ END OF CLASS TMAN ----------------------------

----------------------------------------------------
--BEGIN global functions
--TODO Consider in another class
function id_based_ring_distance(self, a, b)
-- a and b correspond to the data payload of each node 
   
   -- get extra parameters need to calculate the dist function, these paremeters must be initialized with TMAN.set_distFunc_extraParams() method. 
 	 -- in this case the extra parameter will contain the auxiliar 'm' value used to calculate the distance in the ring, e.g., 2^m nodes 
 	 		if self==nil then
	     	log:print("at node: "..job.position.." jaccard self dist_function nill: ")
	     else
	     	log:print("at node: "..job.position.." jaccard self dist_function not nill: "..tostring(self))
	     end
 	 
 	    
 	    if a[1]==nil or b[1]==nil then
 	      log:print("at node: "..job.position.." self either a[1]==nil or b[1]==nil")
 	      return 1
 	    end
 	 
 	    local aux_parameters = self:get_distFunc_extraParams()
 		  
	    for k,v in pairs(a) do
	       log:print("at node: "..job.position.." self a k,v : "..k..", "..v)
	   	end
	   	log:print("at node: "..job.position.." self a[1]: "..a[1])
      for k,v in pairs(b) do
	       log:print("at node: "..job.position.." self b k,v : "..k..", "..v)
	   	end
	  	log:print("at node: "..job.position.." self b[1]: "..b[1])
	    


   		--local result = a[1] - b[1] 
   		--local modope = math.pow(2,aux_parameters[1])
   		--return math.mod(result,modope)
   		
   		local v1 = math.abs(a[1]-b[1])
   		local v2 = math.pow(2, aux_parameters[1]) - v1   		
   		local distance = math.min(v1, v2)
   		
   		 log:print("at node: "..job.position.." self a[1]: "..a[1].." b[1]"..b[1].." aux_parameters[1]"..aux_parameters[1].." distance: "..distance)
   		
   		return distance
end



function jaccard_distance(self, a, b)
      
      if self==nil then
	     	log:print("at node: "..job.position.." jaccard self dist_function nill: ")
	     else
	     	log:print("at node: "..job.position.." jaccard self dist_function not nill: "..tostring(self))
	     end
	     
	     
-- a and b correspond to the data payload of each node 
	--log:print("jaccard distance invoked")
	--if type(a) == "table" and  type(v2) == "table" then
		--log:print("a and b are tables ")
		if #a==0 and #b==0 then  -- if sets are empty similarity is considered 1.
			return 1
		end
		
		local intersec = get_intersection(a,b)
		--log:print("jaccard interesection: "..intersec)
		local union = misc.merge(a,b)
		--log:print("jaccard union: "..union)
		return 1-(#intersec/#union)
		--else
		--log:print("a and b are not tables ")
		--return 0
		--end
	 
end
----------------------------------------------------
function get_intersection(set_a, set_b)
	local result = {}
	  	for i = 1,#set_a do
	    	if contains(set_b, set_a[i]) then 
			result[#result+1]=set_a[i] 
		end
	  	end	
	return result	
end
----------------------------------------------------
function contains(set, elem)
  for i = 1,#set do
    if set[i] == elem then 
			return true 
		end
  end
  return false
end
----------------------------------------------------
function select_topics_according_to_id()
	-- returns specific topics according to the id of the node. 
	-- this function is used to test the clustering
	local topics = {"Agriculture", "Health","Aid","Infrastructure","Climate",
		"Poverty","Economy","Education","Energy","Mining","Science","Technology",
		"Environment","Development","Debt" ,"Protection","Labor","Finances",
		"Trade","Gender"}
	local selected = {}
	local myposition = job.position
  --log:print("node ID: (payload selection) : "..myposition)
	local interval = myposition % 4
	
	if interval == 0 then
		for i=1, 5 do
		  --log:print("Setting payload at node: "..myposition.." payload selected: "..topics[i])
		  selected[#selected+1] = topics[i]
		end
	end
	if interval == 1 then
		for i=6, 10 do
		  --log:print("Setting payload at node: "..myposition.." payload selected: "..topics[i])
		  selected[#selected+1] = topics[i]
		end
	end
	if interval == 2 then
		for i=11, 15 do
		  --log:print("Setting payload at node: "..myposition.." payload selected: "..topics[i])
		  selected[#selected+1] = topics[i]
		end
	end
	if interval == 3 then
		for i=16, 20 do
		  --log:print("Setting payload at node: "..myposition.." payload selected: "..topics[i])
		  selected[#selected+1] = topics[i]
		end
	end
 	return selected
end
----------------------------------------------------

----------------------------------------------------
--END global functions
----------------------------------------------------

--function compute_hash(o)
--	return tonumber(string.sub(crypto.evp.new("sha1"):digest(o), 1, 8), 16)
--end

--TODO the coordinator must initialize node: for all the protocols
--	symetric protocol
function main()
	
	 
	local node = Node.new(job.me, job.position) 
	
  local pss = PSS.new(10, 1, 3, 5, 5, "rand", node)   -- parameters: c (view size) , h (healing), s (swappig), fanout, cyclePeriod, peer_selection_policy , me
  Coordinator.addProtocol("pss1", pss)
  
  local tman_base_protocols={pss}

  local tman = TMAN.new(node, 6, 5, tman_base_protocols, "pss1")   -- parameters: me, view size, cycle_period, base_procotols, active_b_proto, algoId
  
  log:print("at node: "..job.position.." self tman: "..tostring(tman))
 
  Coordinator.addProtocol("tman1", tman)
  Coordinator.showProtocols()

  tman:set_distance_function(tman, jaccard_distance)
  tman:set_node_representation(select_topics_according_to_id())
  
  
  -- test second dist function
 -- tman:set_distance_function(id_based_ring_distance)
 -- local m = {}
 -- m[1] = 7
 -- tman:set_distFunc_extraParams(m)
  
 -- local rep={}
 -- rep[1] = node:getID()
 -- tman:set_node_representation(rep)
  
  -- set log 
  pss:setLog(true)
  tman:setLog(true)
  
  -- launch protocols
  Coordinator.launch(600, 15)  -- parameters: running time in seconds, delay to start each protocol
  
end

events.thread(main)  
events.loop()


