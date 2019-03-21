# Copyright (C) Marc Azar. All rights reserved.
# MIT License. Look at LICENSE.txt for more info
#
## A Nim implementation of Simon Cooke's `Bip Buffer`_
##
## A Bi-partite buffer is similar to a circular buffer, but where data is
## inserted in two revolving regions. This allows reads to return 
## contiguous blocks of memory, even if they span a region that would 
## normally include a wrap-around in a circular buffer. It's especially 
## useful for APIs requiring blocks of contiguous memory, eliminating the 
## need to copy data into an interim buffer before use.
## 
## Usage
## --------------
##  ::
##    import bipbuffer
##
##    # Create buffer with capacity of 4 int items
##    var buffer = newBipBuffer[int](4) 
##    
##    
##    block:
##      # Reserve 4 slots for insert on buffer
##      var reserved = buffer.reserve(4)  
##      
##      # Assign data to buffer slots
##      reserved[0] = 7
##      reserved[1] = 22
##      reserved[2] = 218
##      reserved[3] = 56 
##  
##    # Commit reserved data into an available region
##    buffer.commit(4)  
##    
##    block:
##      # Get stored data in a contiguous block
##      var bloc = buffer.read
##      assert bloc[0] == 7
##      assert bloc[1] == 22
##      assert bloc[2] == 218
##      assert bloc[3] == 56
##    
##    # Mark first two parts of the block as free
##    buffer.decommit(2)  
##    
##    # The block should now contain only the last two values
##    block:
##      bloc = buffer.read 
##      assert bloc[0] == 218
##      assert bloc[1] == 56
##
##  .. _Bip Buffer: https://www.codeproject.com/articles/3479/the-bip-buffer-the-circular-buffer-with-a-twist
##
type
  ## BipBuffer
  ## buffer: Backing store
  ## head: Index of the start of the `A` and `B` regions
  ## tail: Index of the end of the `A` and `B` regions
  ## reserve: Index of the start and end of the reserved region
  ## capacity: Capacity of the buffer sequence
  BipBuffer*[T] =
    object
      buffer: seq[T]
      headA, headB: int
      tailA, tailB: int
      reserveStart, reserveEnd: int

  ## Hack to get the buffer capacity, specific to Nim  
  TGenericSeq =
    object
      length, capacity: int
  PGenericSeq = ptr TGenericSeq

  ## To avoid manipulating the buffer pointer directly, I'm assigning a new
  ## object to hold a copy of the buffer pointer and required slice size to
  ## manipulate
  ShallowSlice*[T] =
    object
      point: ptr [T]
      size: int

template `+`*[T](p: ptr T, off: int): ptr T =
  ## Routine to perform pointer arithmatic. Advances pointer to next position
  ## in a continguous memory block
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

proc `[]`*[T](p: ShallowSlice[T], k: int) : T {.inline.} =
  ## Routine to dereference pointer with assertion not to exceed slice
  ## boundaries
  doAssert k < p.size
  result = (p.point + k)[]

proc `[]=`*[T](p: ShallowSlice[T], k:int, val: T) {.inline.} =
  ## Routine to assign buffer with value at specific index with assertion not
  ## to exceed slice boundaries
  doAssert k < p.size
  (p.point + k)[] = val

proc cap[T](x: seq[T]): int =
  ## Get buffer capacity
  cast[PGenericSeq](x).capacity and not low(int)

proc len*[T](x: ShallowSlice[T]): int =
  ## Get slice length
  x.size

proc len*[T](x: BipBuffer[T]): int =
  ## Get Buffer length
  x.buffer.len

proc clear*(x: var BipBuffer) =
  ## Clears all regions and reservations
  ##
  ## Data in the underlying buffer is unchanged
  x.headA = 0
  x.tailA = 0
  x.headB = 0
  x.tailB = 0
  x.reserveStart = 0
  x.reserveEnd = 0

proc free*(x: var BipBuffer) {.inline} =
  ## Frees and clears the buffer to make available for reuse
  x.buffer.setLen(0)
  x.clear

proc newBipBuffer*[T](length: int): BipBuffer[T] {.inline.} =
  ## Create a buffer of capacity `length` 
  result.clear
  result.buffer = newSeqOfCap[T](length)
  result.buffer.setLen(length)

proc reservedLen*(x: BipBuffer): int =
  ## Return number of reserved elements
  ##
  ## This is the amount of available space for writing data to buffer
  x.reserveEnd - x.reserveStart
 
proc reserve*[T](x: var BipBuffer[T], length: int): ShallowSlice[T] {.raises: [OverflowError], inline.} =
  ## Reserves up to `length` slots of storing data.
  ##
  ## If there is less free space than needed, the buffer size will equal the
  ## free space. It will returns an OverflowError if there is no free space.
  var reserveStart: int
  var freeSpace: int
  if (x.tailB - x.headB) > 0:
    reserveStart = x.tailB
    freeSpace = x.headA - x.tailB
  else:
    let spaceAfterA = x.buffer.cap - x.tailA
    if spaceAfterA >= x.headA:
      reserveStart = x.tailA
      freeSpace = spaceAfterA
    else:
      reserveStart = 0
      freeSpace = x.headA
  
  if freeSpace == 0:
    raise newException(OverflowError, "Not enough space")
  
  let reserveLength = min(freeSpace, length)
  x.reserveStart = reserveStart
  x.reserveEnd = reserveStart + reserveLength
  
  var pBuffer: ptr = addr x.buffer[x.reserveStart]
  result.point = pBuffer
  result.size = reserveLength

proc committedLen*(x: BipBuffer): int =
  ## Returns number of commited elements
  ##
  ## This approximates the size of the buffer that will be returned on 
  ## `read()`
  x.tailA - x.headA + x.tailB - x.headB

proc commit*[T](x: var BipBuffer[T], length: int) {.inline.} =
  ## Commits data unto reserved memory block allowing it to be read
  ##
  ## If `length` is `0` reservation will be cleared wihtout any other changes
  if length == 0:
    x.reserveStart = 0
    x.reserveEnd = 0
    return
  
  let toCommit = min(length, x.reserveEnd - x.reserveStart)
  if (x.tailA - x.headA) == 0 and (x.tailB - x.headB) == 0:
    x.headA = x.reserveStart
    x.tailA = x.reserveStart + toCommit
  elif x.reserveStart == x.tailA:
    x.tailA += toCommit
  else:
    x.tailB += toCommit
  
  x.reserveStart = 0
  x.reserveEnd = 0

proc read*[T](x: var BipBuffer[T]): ShallowSlice[T] {.inline.} =
  ## Retreives available commited data as a contiguous block
  ##
  ## Returns `nil` if no data is available. 
  let dataAvail = x.tailA - x.headA
  if (dataAvail) == 0:
    return
  
  var pBuffer: ptr = addr x.buffer[x.headA]
  result.point = pBuffer
  result.size = dataAvail

proc decommit*[T](x: var BipBuffer[T], length: int) {.inline.} =
  ## Marks the first `length` elements of available data as seen
  ##
  ## Next call of `read()` will not include these elements
  if length >= x.tailA - x.headA:
    x.headA = x.headB
    x.tailA = x.tailB
    x.headB = 0
    x.tailB = 0
  else:
    x.headA += length

proc isEmpty*(x: BipBuffer): bool =
  ## Check if buffer is empty
  reservedLen(x) == 0 and committedLen(x) == 0
