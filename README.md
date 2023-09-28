# bash_nd_array
basic framework for creating and using n-dimensional nested arrays in bash

**OVERVIEW**

There are 5 functions:

* nd_usage gives a brief usage example
* nd_create sets up the nameref framework and declares the arrays
* nd_set writes data into the arrays at the end on the namerefs (the A_0 and A_1 arrays in the simple example above)
* nd_get reads data out of the arrays. You can define lists/ranges on indices for any dimension and it will output all the data that falls into the n-dimensional slice of the array.
* nd_clear unsets all the array and nameref variables

**METHODOLOGY**

It involves creating a framework of nameref arrays to handle all the dimensions except the last one (which is saved in the arrays themselves. The idea is to do something like

```
declare -n a_0='A_0'
declare -n a_1='A_1'
A=(a_0 a_1)
A_0=(1 2 3)
A_1=(4 5 6)
```

So to get the data at (1,2), you do ${A[1]} which gives a_1 which namerefs to A_1 then ${A_1[2]} which gives the actual data. The use of the a_1 and a_0 are because bash doesnt directly support doing, say, declare -n A[0]=A_0...you have to nameref a dummy variable and then store that in an array.

**USAGE**

```
# # # # #  generate nameref framework. 
# note: dont include the last dimension

source <(nd_create -a A 2 3 4)
   
# # # # # set array values
# pass data to be set on STDIN, and use function inputs to define basename + index ranges

source <(seq 1 $(( 2 * 3 * 4 * 5 )) | nd_set A 0:1 0:2 0:3 0:4)
    
# # # # # extract various slices from the array

nd_get A 0 \@ \@ \@
nd_get A \@ 0  @ \@
nd_get A \@ \@ 0 \@
nd_get A \@ \@ \@ 0 
nd_get A \* '0 2' [1:3] 0:2
```
