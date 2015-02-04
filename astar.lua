PriorityQueue = {

    new = function()
      local o = {nodes={}, n = 0}
      setmetatable(o, {__index=PriorityQueue})
      return o
    end,

    put = function(self, node, cost)
      self.nodes[cost] = self.nodes[cost] or {}
      for i, ncost in pairs(self.nodes) do
        for j, n in pairs(ncost) do
          if node == n then
            table.remove(self.nodes[i], j)
            self.n = self.n-1
          end
        end
      end
      table.insert(self.nodes[cost], node)
      self.n = self.n + 1
    end,

    get = function(self)
      local min = 1/0
      local ret
      for cost, nodes in pairs(self.nodes) do
        min = cost < min and cost or min
      end
      if self.nodes[min] then
        ret = table.remove(self.nodes[min])
        if #self.nodes[min] == 0 then
          self.nodes[min] = nil
        end
        self.n = self.n - 1
        return ret
      else
        return nil
      end
    end
}

AStar = {
  cachedNeighbors = {n=0},

  heuristic = function(a,b)
--    return  (((a.position.x - b.position.x)^2 + (a.position.y - b.position.y)^2)^0.5) --#732, 733 #1317 1419 (#1371 1458 pen = 3)
        local dx = math.abs(a.position.x - b.position.x)
        local dy = math.abs(a.position.y - b.position.y)
        local min = dx < dy and dx or dy
      return 1.4*min+math.abs(dx-dy) --#667 692 #1049 1210 (#1059 1213 pen=3, squiggly)
  end,

  tiebreaker = function(current, start, goal)
    local dx1 = current.position.x - goal.position.x
    local dy1 = current.position.x - goal.position.x
    local dx2 = start.position.x - goal.position.x
    local dy2 = start.position.x - goal.position.x
    local cross = math.abs(dx1*dy2 - dx2*dy1)*0.001
    return cross
  end,

  gcost = function(a,b, goal)
    local penalty = a.travelDir ~= b.travelDir and 5 or 0 --
    return AStar.heuristic(a,b) + penalty
  end,

  getKey = function(node)
    --debugDump(node,true)
    return node.position.x.."|"..node.position.y.."|"..node.direction.."|"..node.name.."|"..node.travelDir
  end,

  getNeighbors = function(node)
    local key = AStar.getKey(node)
    if not AStar.cachedNeighbors[key] then
      AStar.cachedNeighbors[key] = {}
      AStar.cachedNeighbors.n = AStar.cachedNeighbors.n+1
      for i=0,2 do
        local newTravel, node = FARL.getRail(node, node.travelDir, i)
        if type(newTravel) == "number" then
          node.travelDir = newTravel
        else
          node = node[1]
          node.travelDir = newTravel[1]
        end
        --if AStar.validNode(node) then
          AStar.cachedNeighbors[key][i+1] = node
        --end
      end
    end
    return AStar.cachedNeighbors[key]
  end,

  validNode = function(node)
    if game.canplaceentity{name= node.name, position = node.position} then
      return true
    else
      if node.name == "straight-rail" then
--        local v = {{x=0,y=0},{x=-1,y=-1},{x=0,y=-1},{x=-1,y=0}}
--        for i=1,4 do
--          local tileName = game.gettile(node.position.x+v[i].x, node.position.y+v[i].y).name
--          if tileName == "out-of-map" and tileName == "deepwater" and tileName == "deepwater-green" and tileName == "water" and tileName == "water-green" then
--            return false
--          end
--        end
      else
--        for i=1,10 do
--          local tileName = game.gettile(node.x+v[i].x, node.y+v[i].y).name
--          if tileName == "out-of-map" and tileName == "deepwater" and tileName == "deepwater-green" and tileName == "water" and tileName == "water-green" then
--            return false
--          end
--        end
      end
      return false
    end
  end,

  goalReached = function(current, goal)
    if  current.position.x == goal.position.x and
      current.position.y == goal.position.y and
      current.direction == goal.direction and
      current.travelDir == goal.travelDir then
      return true
    else
      return false
    end
  end,

  astar = function(start, goal, frontier, cameFrom, cost_so_far, max)
    --AStar.cachedNeighbors = {n=0}
    local frontier = frontier -- open list
    local cameFrom = cameFrom or {} 
    local cost_so_far = cost_so_far or {} --closed list     
    if not frontier then
      frontier = PriorityQueue.new() 
      frontier:put(start, 0)
      cameFrom[start] = "Null"
      cost_so_far[AStar.getKey(start)] = 0
    end
    --debugDump({start,goal},true)
    local count = 1
    local max = max or 200
    local current, path
    while frontier.n > 0 and count < max do
      count = count+1
      current = frontier:get()
      -- done
      --debugDump({n=frontier.n, current},true)
      if current ~= nil then
        if AStar.goalReached(current, goal) then
          path = AStar.getPath(start,current,cameFrom)
          break
        end
        -- get connected nodes from current
        local neighbors = AStar.getNeighbors(current)
        --debugDump({nei=neighbors, current = current},true)
        for i=1,#neighbors do
          local next = neighbors[i]
          local keyNext = AStar.getKey(next)
          local new_cost = cost_so_far[AStar.getKey(current)] + AStar.gcost(current, next, goal)
          if not cost_so_far[keyNext] or new_cost < cost_so_far[keyNext] then
            cost_so_far[keyNext] = new_cost
            local priority = new_cost + AStar.heuristic(goal, next) + AStar.tiebreaker(current,start,goal)
            -- w tiebreaker w penalty(2.5): #732, 733 (squiggly)
            -- w/o tie w/o penalty : #806, 835 (squiggly)
            -- w tie w/o pen: #806, 769
            frontier:put(next, priority)
            cameFrom[next] = current
          end
        end
      end
    end
    return path, frontier, cameFrom, cost_so_far
  end,

  getPath = function(start, goal, cameFrom)
    local current = goal
    local path = {current}
    while current and not AStar.goalReached(current, start) do
      current = cameFrom[current]
      table.insert(path, current)
    end
    return path
  end
}