.data

strMenuHr: .asciiz "##################################################### \n"
strMenuOpts: .asciiz "Select an option: \n"
srtMenuOp1: .asciiz "1 - Load image into display \n"
strMenuOp2: .asciiz "2 - Rotate colors \n"
strMenuOp3: .asciiz "3 - Rotate image \n"
strMenuOp4: .asciiz "4 - Invert colors \n"
strMenuOp5: .asciiz "5 - Greyscale \n"
strMenuOp6: .asciiz "6 - Contrast adjust \n"

strErrOpenFile: .asciiz "Error opening the file. Are you sure that the name is correct?\n"
strErrReadFile: .asciiz "Error reading the file. Are you sure that it is a bmp compatible file? \n"
filename: .asciiz "img.bmp"
header: .space 54	#54 bytes is the standard header size for a true color bmp image 
					#		to read
					# The pixel size must bit 3 bytes (24bits) too.
					# Uncompressed image as well
.text

main:

	jal loadImage
	#Will read the image at the same directory as mars is located and loads and copy at $sp and
	#	$gp. The idea behind it is making two copies is that one of these will be the displayed 
	#	image with (or without) filters applied. If the user chooses he can reset the image to 
	#	the the original state wich means a copy of the data at $sp to $gp.
	#	Use: $a0~$a2, $t0~$t9, $v0 and $v1. $v0 and $v1 will be the returns with the address to the
	#		data info and the data.

	jal endProgram #Lembrar de devolver toda a memória
#end main

loadImage:
	add $t6, $ra, $zero

	la $a0, filename
	jal openFile
		#openFile will take $a0 as the name of the file and will take care of
		#		the rest of the parameters to open the file.
		#Use: $a0, $a1, $v0. $v0 will return file descriptor

	la $a1, header 		# Address of the space to copy the file header
	li $a2, 54			# No. of bytes to read
	jal readHeader
		#readHeader will take openFile's return (file descriptor $v0) plus $a1 and $a2.
		#Use: $a0, $a1, $a2, $v0. $a0 will return the memory address with the raw data of the header
	
	add $t7, $a0, $zero #save file descriptor to use in storeImage procedure

	la $a0, header 		#$a0 will be the address of the readen data.
						#It's important that the header follow the 54 byte rule.
	jal analyseHeader
		#analyseHeader will analyse the info that was read by readHeader and will put the 
		#		most relevant info at $t8 and will alocate the suficient amount of stack
		#		to $t9 to store the file in storeImage procedure.
		#Use $t0, $t1, $t2, $t3, $t4. Will output $t8 as the relevant info and $t9 as the image data.

	jal storeImage
		#Use $a0, $a1, $a2, $t8, $t9, $t7 and $v0.

	jal dispOriginal
		#Use $t0, $t1, $t2, $t3, $t4, $t5, $t8 and $t9.

	add $v0, $t8, $zero 	#Return the data info
	add $v1, $t9, $zero 	#Return the data

	add $ra, $t6, $zero
	jr $ra
#end loadImage

dispOriginal:
	la $t0, 0x10008000		#screen address
	add $t1, $t9, $zero 	#iterative data address
	li $t2, 0 			#index
	lw $t3, 0($t8)			#limit number of iterations
	loop_DispOriginal:
		beq $t2, $t3, endProgram

		lb $t4, 0($t1)

		lb $t5, 1($t1)
		sll $t5, $t5, 8
		add $t4, $t4, $t5

		lb $t5, 2($t1)
		sll $t5, $t5, 16
		add $t4, $t4, $t5

		sw $t4, 0($t0)
		add $t1, $t1, 3
		add $t0, $t0, 4
		add $t2, $t2, 3
		j loop_DispOriginal
	jr $ra
#end dispOriginal


storeImage:
	add $a1, $t9, $zero
	lw $a2, 0($t8)
	add $a0, $t7, $zero
	li $v0, 14			# read file parameter
	syscall				
	blt $v0, $zero, errReadFile
	jr $ra
#end storeImage

analyseHeader:
	la $t0, header

	#errorControl:
		#fileHeaderCheck
			#The first 2 bytes are suposed to be (424d)h
			lb $t1, 0($t0)	#Should be (42)h
			lb $t2, 1($t0)	#Should be (4D)h
			bne $t1, 0x42, errReadFile
			bne $t2, 0x4d, errReadFile

			#The 7th, 8th, 9th and 10th bytes are reserved and suposed to be 0
			#Since memory is zero-indexed we start by the address of number 6
			lb $t1, 6($t0)
			lb $t2, 7($t0)
			lb $t3, 8($t0)
			lb $t4, 9($t0)
			bne $t1, $zero, errReadFile
			bne $t2, $zero, errReadFile
			bne $t3, $zero, errReadFile
			bne $t4, $zero, errReadFile

			#Since we are dealing with a True Color bmp image, we should check if the
			#	BfOffSetBits field is (54)d as expected.
			lb $t1, 10($t0)
			bne $t1, 54, errReadFile
		#end fileHeaderCheck

		#bitmapHeaderCheck
			#Checking BiSize field that has a fixed value of (40)d
			lb $t1, 14($t0)
			bne $t1, 40, errReadFile

			#Checking the BiPlane field that has a fixed value of (1)d
			lb $t1, 26($t0)
			bne $t1, 1, errReadFile

			#Checking BiBitCount field, that says how much bits a pixel need
			#	If more or less than 24 the program will abort.
			lb $t1, 28($t0)
			bne $t1, 24, errReadFile

			#Checking BiCompress field, which must be zero
			lb $t1, 30($t0)
			bne $t1, 0, errReadFile
		#end bitmapHeaderCheck
	#end errorControl

	#At this point we already know that the image is the type we are looking for
	#Lets save some important data then!

	#dataSave:
		# $t8 will be the adress located in the stack that will store:
		#		0($t8) = Image start address
		# 		4($t8) = Image width (largura) in pixels
		#		8($t8) = Image height (altura) in pixels
		# This memory segment will be used as reference for the various operations
		#		that will be performed.

		addi $sp, $sp, -12
		add $t8, $sp, $zero

		#loadWidth:
			#Load each byte of the field and dislocate to compose the full int number
			lb $t1, 18($t0)
			lb $t2, 19($t0)
			sll $t2, $t2, 8
			add $t1, $t1, $t2
			lb $t2, 20($t0)
			sll $t2, $t2, 16
			add $t1, $t1, $t2
			lb $t2, 21($t0)
			sll $t2, $t2, 24
			add $t1, $t1, $t2
		#end loadWidth

		#loadHeight:
			#Load each byte of the field and dislocate to compose the full int number
			lb $t2, 22($t0)
			lb $t3, 23($t0)
			sll $t3, $t3, 8
			add $t2, $t2, $t3
			lb $t3, 24($t0)
			sll $t3, $t3, 16
			add $t2, $t2, $t3
			lb $t3, 25($t0)
			sll $t3, $t3, 24
			add $t2, $t2, $t3
		#end loadWidth		

		#I know that lwr would do the trick but since it wasnt working at the 
		#	time, i did this not so elegant thing with loadHeight and loadWidth that work.

		#loadSize: #Its important to know the size of the image for the apropriate
					# stack pointer decrement
			#Load each byte of the field and dislocate to compose the full int number
			lb $t3, 34($t0)
			lb $t4, 35($t0)
			sll $t4, $t4, 8
			add $t3, $t3, $t4
			lb $t4, 36($t0)
			sll $t4, $t4, 16
			add $t3, $t3, $t4
			lb $t4, 37($t0)
			sll $t4, $t4, 24
			add $t3, $t3, $t4

		#end loadSize	

		#Save obtained values at $t8
		sw $t3, 0($t8)
		sw $t1, 4($t8)
		sw $t2, 8($t8)

		#Allocate the size of the bitmap of the image in bytes at the stack.
		sub $sp, $sp, $t3
		add $t9, $sp, $zero


	#end dataSave	

	jr $ra

#end analyseHeader

openFile:
	#sycall for open the file
	li $v0, 13			# parametro p chamada de abertura
	li $a1, 0			# flags (0=read, 1=write)
	li $a2, 0			# mode = desnecessário
	syscall				# devolve o descritor (ponteiro) do arquivo em $v0
	blt $v0, $zero, errOpenFile
	jr $ra
#end openFile

readHeader:
	move $a0, $v0
	li $v0, 14			# parametro de chamada de leitura de arquivo	
	syscall				# devolve o número de caracteres lidos
	blt $v0, $zero, errReadFile
	jr $ra
#end readHeader


errOpenFile:
	#If the file does not exists this function will be triggered
	la $a0, strErrOpenFile
	jal printStr
	jal endProgram
#end errOpenFile

errReadFile:
	#If the file information does not come out as it should, this function will be triggered
	la $a0, strErrReadFile
	jal printStr
	jal endProgram
#end errReadFile

printStr:
	li $v0, 4
	syscall
	jr $ra
#end printStr

endProgram:
	li $v0, 10
	syscall


