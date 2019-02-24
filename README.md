# BipBuffer
A Nim implementation of Simon Cooke's <a class="external reference" href="https://www.codeproject.com/articles/3479/the-bip-buffer-the-circular-buffer-with-a-twist">Bip Buffer</a>. A Bi-partite buffer is similar to a circular buffer, but where data is inserted in two revolving regions. This allows reads to return contiguous blocks of memory, even if they span a region that would normally include a wrap-around in a circular buffer. It's especially useful for APIs requiring blocks of contiguous memory, eliminating the need to copy data into an interim buffer before use.

## Example Usage                                                        
```
import bipbuffer

var buffer = newBipBuffer[int](4) # Create buffer wuth capacity of 4 int items
 
 block:
  var reserved = buffer.reserve(4)  # Reserve 4 slots for insert on buffer
  reserved[0] = 7 # Assign data to buffer slots
  reserved[1] = 22
  reserved[2] = 218
  reserved[3] = 56

buffer.commit(4)  # Commit reserved data into an available region on buffer

block:
  var bloc = buffer.read # Get stored data in a contiguous block
  assert bloc[0] == 7
  assert bloc[1] == 22
  assert bloc[2] == 218
  assert bloc[3] = 56

buffer.decommit(2)  # Mark first two parts of the block as free

block:
  bloc = buffer.read # The block should now contain only the last two values
  assert bloc[0] == 218
  assert bloc[1] == 56
```
## Installation
Install <a class="external reference" href="https://nim-lang.org/install.html">Nim</a> for Windows or Unix by following the instructions in , or preferably by installing <a class="reference external" href="https://github.com/dom96/choosenim">choosenim</a>

Once ```choosenim``` is installed you can ```nimble install bipbuffer``` to pull the latest bipbuffer release and all its dependencies

## Documentation
Documentation can be found <a class="external reference" href="https://htmlpreview.github.io/?https://github.com/MarcAzar/BipBuffer/blob/master/docs/bipbuffer.html">here</a>
