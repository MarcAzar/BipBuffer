import bipbuffer

when isMainModule:
  var buffer: BipBuffer[int]
  var bloc: ShallowSlice[int]
  var reserved: ShallowSlice[int]
  var flag = false

  block:
    doAssert newBipBuffer[int](3) is BipBuffer[int]
    doAssert newBipBuffer[string](3) is BipBuffer[string]
    doAssert newBipBuffer[char](3) is BipBuffer[char]
    echo "Passed declaration test"

  block:
    buffer = newBipBuffer[int](3)
    bloc = buffer.read
    doAssert bloc.isNil
    echo "Passed read empty test"

  block:
    buffer = newBipBuffer[int](3)
    reserved = buffer.reserve(2)
    bloc = buffer.read
    doAssert bloc.isNil
    echo "Passed read uncommitted test"

  block:
    buffer = newBipBuffer[int](3)
    doAssert buffer.reservedLen == 0
    block:
      reserved = buffer.reserve(3)
      doAssert reserved.len == 3
    doAssert buffer.reservedLen == 3
    echo "Passed reserve greater than overall length test"

  block:
    buffer = newBipBuffer[int](4)
    block:
      reserved = buffer.reserve(3)
      reserved[0] = 7 
      reserved[1] = 22
      reserved[2] = 218
    doAssert buffer.len == 0
    buffer.commit(3)
    doAssert buffer.len == 3
    doAssert buffer.reservedLen == 0  
    bloc = buffer.read
    doAssert bloc.len == 3
    doAssert bloc[0] == 7
    doAssert bloc[1] == 22
    doAssert bloc[2] == 218
    echo "Passed commit and fetch test"
  
  block:
    buffer = newBipBuffer[int](4)
    reserved = buffer.reserve(4)
    reserved[0] = 7
    reserved[1] = 22
    reserved[2] = 218
    reserved[3] = 56
    buffer.commit(4)
    try:
       reserved = buffer.reserve(1)
    except:
      flag = true
    
    doAssert flag
    echo "Passed reserve full test"

  block:
    buffer = newBipBuffer[int](4)
    block:
      reserved = buffer.reserve(4)
      reserved[0] = 7
      reserved[1] = 22
      reserved[2] = 218
      reserved[3] = 56
    buffer.commit(4)
    buffer.decommit(2)
    block:
      bloc = buffer.read
      doAssert bloc.len == 2
      doAssert bloc[0] == 218
      doAssert bloc[1] == 56
    buffer.decommit(1)
    block:
      bloc = buffer.read
      doAssert bloc.len == 1
      doAssert bloc[0] == 56
    echo "Passed decommit test"

  block:
    buffer = newBipBuffer[int](4)
    block:
      reserved =  buffer.reserve(4)
      reserved[0] = 7
      reserved[1] = 22
      reserved[2] = 218
      reserved[3] = 56
    buffer.commit(4)
    buffer.decommit(2)
    block:
      reserved = buffer.reserve(4)
      doAssert buffer.reservedLen == 2
      reserved[0] = 49
      reserved[1] = 81
    buffer.commit(2)
    block:
      bloc = buffer.read
      doAssert bloc.len == 2
      doAssert bloc[0] == 218
      doAssert bloc[1] == 56
    buffer.decommit(2)
    block:
      bloc = buffer.read
      doAssert bloc.len == 2
      doAssert bloc[0] == 49
      doAssert bloc[1] == 81
    echo "Passed reserve after full cycle test"

  block:
    buffer = newBipBuffer[int](4)
    block:
      reserved =  buffer.reserve(4)
      reserved[0] = 2
      reserved[1] = 23
      reserved[2] = 99
      reserved[3] = 126
    doAssert buffer.reservedLen == 4
    buffer.commit(4)
    doAssert buffer.reservedLen == 0
    buffer.clear
    doAssert buffer.len == 0

  buffer.free
  doAssert buffer.len == 0
  echo "Passed free buffer test"

  echo "Success!!!"
