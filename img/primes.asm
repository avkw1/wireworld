Программа поиска простых чисел (с сайта quinapalus.com). Автор: Michael Fryers.

Reg  Hex  Disassembly

 1  001e  MOV R0 ,R30  ; set display to 2
 2  361f  MOV R54,R31  ; initialise mask register for sign bit test
 3  2021  MOV R32,R33  ; set candidate prime p=3
 4  3c22  MOV R60,R34  ; the trial divisor q is stored in the adder as its
                       ; negative: here it is initialised to -1, i.e. q=1
 5  3d23  MOV R61,R35  ; other summand=-2
 6  3c3d  MOV R60,R61  ; next trial divisor q=q+2
 7  3d20  MOV R61,R32  ; move p to adder summand input a, which holds remainder
 8  3924  MOV R57,R36  ; for the first time round the loop, set the target
                       ; for the branch if subtraction gives zero to 20: this
                       ; detects the case p==q, which means we have done all
                       ; the trial divisors and p is prime
 9  3725  MOV R55,R37  ; if subtraction result non-zero, target is 13
10  383d  MOV R56,R61  ; test a-q
11  3f38  MOV R63,R56  ; branch to selected target
12  3d3d  MOV R61,R61  ; a-=q
13  3d3d  MOV R61,R61  ; a-=q (continuing here if subtraction result not zero)
14  353d  MOV R53,R61  ; move a-q to and-not register to check sign
15  3926  MOV R57,R38  ; target is 9 if a-q positive (round subtraction loop
                       ; again)
16  3727  MOV R55,R39  ; else target is 5 (q does not divide p, so try next q)
17  3836  MOV R56,R54  ; test a-q AND 0x8000
18  3f38  MOV R63,R56  ; branch to selected target
19  3928  MOV R57,R40  ; reset target for other branch to 21 (a zero result
                       ; from the subtraction now indicates q properly
                       ; divides p and so p is composite)
20  0020  MOV R0 ,R32  ; p is prime: write it to the display
21  3d20  MOV R61,R32  ; move p to adder
22  3c1e  MOV R60,R30  ; other summand=2
23  3f29  MOV R63,R41  ; goto 4 to try new p
24  203d  MOV R32,R61  ; p+=2
25                     ; unused
26                     ; unused
27                     ; unused
28                     ; unused
29                     ; unused
30  0002               ; constant 2
31  7fff               ; constant mask for sign bit testing
32  0005               ; current candidate p
33  0003               ; constant 3
34  fffe               ; constant -1
35  fffd               ; constant -2
36  0014  20           ; branch target: trial divisor q equal to candidate p,
                       ; and hence prime found
37  000d  13           ; branch target: trial divisor q less than candidate p
38  0009   9           ; branch target: more subtractions to do
39  0005   5           ; branch target: next trial divisor q
40  0015  21           ; branch target: subtraction gave zero, so p composite
41  0004   4           ; branch target: next candidate p
42  fffc               ; constant -3

Содержимое памяти:

0x001e
0x361f
0x2021
0x3c22
0x3d23
0x3c3d
0x3d20
0x3924
0x3725
0x383d
0x3f38
0x3d3d
0x3d3d
0x353d
0x3926
0x3727
0x3836
0x3f38
0x3928
0x0020
0x3d20
0x3c1e
0x3f29
0x203d
0x0000
0x0000
0x0000
0x0000
0x0000
0x0002
0x7fff
0x0005
0x0003
0xfffe
0xfffd
0x0014
0x000d
0x0009
0x0005
0x0015
0x0004
0xfffc
