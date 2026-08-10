term.clear()
term.setCursorPos(1,1)

print("==========================")
print(" PAISACRAFT INSTALL STATION")
print("==========================")
print("")

local drive = peripheral.find("drive")

if not drive then
    print("No se encontro Disk Drive.")
    return
end

local side = peripheral.getName(drive)

if not disk.isPresent(side) then
    print("Inserta el disquete.")
    return
end

local path = disk.getMountPath(side)

print("Disco encontrado:")
print(path)
print("")

print("Esperando turtle...")

while true do

    local id = rednet.lookup("paisacraft_install")

    if id then

        print("")
        print("Turtle encontrada:")
        print(id)

        rednet.send(id,{
            command="INSTALL"
        })

        print("Orden enviada.")

        break

    end

    sleep(1)

end
