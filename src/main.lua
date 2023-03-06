local loop, err = newLoop()
if err then
    print(err)
end

err = loop:spawn(coroutine.create(function()
    local socket, err = loop:tcpConnect("93.184.216.34", 80)
    if err then
        print(err)
        return
    end

    print("success point")
end))
if err then
    print(err)
end

err = loop:run()
if err then
    print(err)
end
