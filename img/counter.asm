﻿Программа-счётчик.
Выводит на экран числа 0, 1, 2, 3, ...

 1  3d05  MOV R61,R5   ; R61 := 1
 2  3c3d  MOV R60,R61  ; R60 := R60 + R61
 3  3f06  MOV R63,R6   ; Переход на адрес 2
 4  003c  MOV R0 ,R60  ; R60 -> экран (branch delay slot)
 5  0001  1
 6  0002  2

Содержимое памяти:

0x3d05
0x3c3d
0x3f06
0x003c
0x0001
0x0002
