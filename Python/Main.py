import random
import pprint
from Three_D_Generator import three_d_generator
from Three_D_Generator import three_d__output_generator
from Three_D_Generator import kernel_three_d_generator
from Three_D_to_One_D import one_d_gen
from One_D_to_Three_D import one_d_to_three_d_converter
from Zero_Padding import zero_padding
import numpy as np
import math
from scipy import ndimage
from scipy import signal
import torch
import pickle
from torch import nn




data_folder = "C:/Users/Admin/Desktop/Verilog Projects/Memory_Data/"





output_file = open("myfile2.txt", "w")
output_file_2 = open("OUTPUT_COMPARE.txt", "w")
output_file_3 = open(data_folder + "Bmem_no_batch.txt", "w")
output_file_4 = open("OUTPUT_COMPARE_HEX.txt", "w")
output_file_5 = open(data_folder +"Bmem.txt", "w")
output_file_8 = open("OUTPUT_COMPARE_NO_BATCH.txt", "w")


###########################PE's################################

output_file_6 = open(data_folder + "pe_00.mem", "w")
output_file_7 = open(data_folder + "pe_10.mem", "w")
output_file_9 = open(data_folder + "pe_20.mem", "w")
output_file_10 = open(data_folder + "pe_30.mem", "w")
output_file_11 = open(data_folder + "pe_01.mem", "w")
output_file_12 = open(data_folder + "pe_11.mem", "w")
output_file_13 = open(data_folder + "pe_21.mem", "w")
output_file_14 = open(data_folder + "pe_31.mem", "w")
output_file_15 = open(data_folder + "pe_02.mem", "w")
output_file_16 = open(data_folder + "pe_12.mem", "w")
output_file_17 = open(data_folder + "pe_22.mem", "w")
output_file_18 = open(data_folder + "pe_32.mem", "w")
output_file_19 = open(data_folder + "pe_03.mem", "w")
output_file_20 = open(data_folder + "pe_13.mem", "w")
output_file_21 = open(data_folder + "pe_23.mem", "w")
output_file_22 = open(data_folder + "pe_33.mem", "w")



# define height, width and depth(channels) of input tensor, kernel and output tensor respectively
# pointers is a list of pointers that would point to the end of a W*Ic block in memory
# padding = n --> (nxn padding)
# stride = n --> (nxn stride)

#Simulation Parameters

batch_size = 2 #K_TL

M = 8
N = 16
output_chans = 384
C_width = 5

LM = 1
TM = 1  # (output_chans / N)

padding = 1
stride = 1

stream_width = M
C_stream_width = N

i_dimension = 13
i_rows = 13
i_cols = 13
i_chans = 256

i_z_rows = i_rows + 2
i_z_cols = i_cols + 2
i_z_chans = i_chans

k_dimension = 3
k_rows = 3
k_cols = 3
k_chans = 256

o_dimension = math.floor((i_dimension + (2 * padding) - k_dimension)/stride) + 1

# FOR STRIDE = 1:
#o_dimension = i_dimension + (2* (math.floor(k_dimension/2))) - (k_dimension - 1)
print(o_dimension)
o_rows = o_dimension
o_cols = o_dimension
#o_chans = 3

pointers = []

# generate a 3D matrix and store it in input_tensor
input_tensor = three_d_generator(i_rows, i_cols, i_chans)
input_tensor2 = three_d_generator(i_rows, i_cols, i_chans)
print('generated 3D matrix 1:')
pprint.pprint(input_tensor)
print('generated 3D matrix 2:')
pprint.pprint(input_tensor2)

input_tensor_one_d = []
input_tensor_one_d = one_d_gen(input_tensor, i_rows, i_cols, i_chans)
print ('no padding :')
print(input_tensor_one_d)
# Zero Pad the input tensor --> change this to automatic zero padding at next stage
zero_padding_input_tensor = zero_padding(input_tensor, i_rows, i_cols, i_chans)
print('input_tensor 3D matrix with zero padding :')
pprint.pprint(zero_padding_input_tensor)


input_tensor_one_d2 = []
input_tensor_one_d2 = one_d_gen(input_tensor2, i_rows, i_cols, i_chans)
print ('no padding 2:')
print(input_tensor_one_d2)
# Zero Pad the input tensor --> change this to automatic zero padding at next stage
zero_padding_input_tensor2 = zero_padding(input_tensor2, i_rows, i_cols, i_chans)
print('input_tensor 3D matrix with zero padding 2:')
pprint.pprint(zero_padding_input_tensor2)


# use three_d_generator to generate 3D unique kernel
kernel_tensor = []
kernel_tensor2 = []
for kt in range(output_chans):
    kernel = three_d_generator(k_rows, k_cols, k_chans)
    kernel_tensor2.append(kernel)
    kernel_one_d_stream = one_d_gen(kernel, k_rows, k_cols, k_chans)
    pointer_index = k_rows * k_cols * k_chans
    for i in range(pointer_index, len(kernel_one_d_stream)):
        kernel_one_d_stream.pop()
    kernel_tensor.append(kernel_one_d_stream)

print(f'kernel_tensor : {kernel_tensor}')
print(f'kernel_tensor LENGTH : {len(kernel_tensor)}')
print(f'kernel_tensor[last][0] : {kernel_tensor[0][len(kernel_one_d_stream)-1]}')
print(f'kernel_tensor[0][1] : {kernel_tensor[0][1]}')
print(f'kernel_tensor[0][2] : {kernel_tensor[0][2]}')
print(f'kernel_tensor[1][0] : {kernel_tensor[1][0]}')
print(f'kernel_tensor[1][1] : {kernel_tensor[1][1]}')

'''
kernel =  three_d_generator(k_rows, k_cols, k_chans)
kernel2 =  three_d_generator(k_rows, k_cols, k_chans)
kernel3 =  three_d_generator(k_rows, k_cols, k_chans)
kernel4 =  three_d_generator(k_rows, k_cols, k_chans)


kernel_one_d_stream = one_d_gen(kernel, k_rows, k_cols, k_chans)
kernel_one_d_stream2 = one_d_gen(kernel2, k_rows, k_cols, k_chans)
kernel_one_d_stream3 = one_d_gen(kernel3, k_rows, k_cols, k_chans)
kernel_one_d_stream4 = one_d_gen(kernel4, k_rows, k_cols, k_chans)
'''
# use kernel_three_d_generator to generate 2D kernel and copy to 3 channels
# twoD_kernel = []
# kernel, twoD_kernel = kernel_three_d_generator(k_rows, k_cols, k_chans)\
# print(f'2D kernel: {twoD_kernel}')
print('3D Kernel :')
pprint.pprint(kernel)


# generate a stream of 1D data from the 3D matrix and store in one_d_stream
# Uncomment this for anything other than 1D
batch_size = 2

one_d_stream = one_d_gen(zero_padding_input_tensor, i_z_rows, i_z_cols, i_z_chans)
pointer_index = i_z_rows*i_z_cols*i_z_chans

for i in range(pointer_index, len(one_d_stream)):
    pointers.append(one_d_stream.pop())
pointers.reverse()



one_d_stream2 = one_d_gen(zero_padding_input_tensor2, i_z_rows, i_z_cols, i_z_chans)
pointers2 = []
for i in range(pointer_index, len(one_d_stream2)):
    pointers2.append(one_d_stream2.pop())
pointers2.reverse()

########################################################################################
#Interleaving stuff:
pointer_index2 = i_rows * i_cols * i_chans

for i in range(pointer_index2, len(input_tensor_one_d)):
    input_tensor_one_d.pop()
    input_tensor_one_d2.pop()


print(f"popped : {pointers2}")
print(f'one_d_stream1 : {one_d_stream}')


print(f'one_d_stream2 : {one_d_stream2}')


interleave_ctr = 0
j = 0
k = 0
############# FOR NO AUTOMATIC PADDING######################
'''
interleaved_one_d_stream = [0] * (len(one_d_stream) + len(one_d_stream2))
for i in range((len(one_d_stream) + len(one_d_stream2))):
    if interleave_ctr == 0:
        if j < len(one_d_stream):
            interleaved_one_d_stream[i] = one_d_stream[j]
            j = j+1
            if ((i+1) % i_chans) == 0:
                interleave_ctr = interleave_ctr + 1
    elif interleave_ctr == 1:
        if k < len(one_d_stream2):
            interleaved_one_d_stream[i] = one_d_stream2[k]
            k = k+1
            if ((i+1) % i_chans) == 0:
                interleave_ctr = 0

print(f'interleaved : {interleaved_one_d_stream}')
'''

###############FOR AUTOMATIC ZEOR PADDING#####################
interleaved_one_d_stream = [0] * (len(input_tensor_one_d) + len(input_tensor_one_d2))
for i in range((len(input_tensor_one_d) + len(input_tensor_one_d2))):
    if interleave_ctr == 0:
        if j < len(input_tensor_one_d):
            interleaved_one_d_stream[i] = input_tensor_one_d[j]
            j = j+1
            if ((i+1) % i_chans) == 0:
                interleave_ctr = interleave_ctr + 1
    elif interleave_ctr == 1:
        if k < len(input_tensor_one_d2):
            interleaved_one_d_stream[i] = input_tensor_one_d2[k]
            k = k+1
            if ((i+1) % i_chans) == 0:
                interleave_ctr = 0

print(f'interleaved : {interleaved_one_d_stream}')

words_per_packet = 2
x=0
y = 0
hexlist = []
for y in range(len(interleaved_one_d_stream)):
    hex_value = hex(interleaved_one_d_stream[y]).split('0x')[1]
    if (len(hex_value) == 1):
        hex_value = "0"+hex_value
    hexlist.append(hex_value)
#hexlist = [(hex(interleaved_one_d_stream[x])).split('0x')[1] for x in range(len(interleaved_one_d_stream))]

listToStr = ''
x = 0
print(f'hexlist[0] : {hexlist[0]}')
for x in range(0, len(hexlist), 1):
    if ((x+1) % stream_width) == 0:
        listToStr = listToStr + hexlist[x] + ' '
    else:
        listToStr = listToStr + hexlist[x]



print(f'hexlist: {hexlist}')
# listToStr = ' '.join(map(str, hexlist))
output_file_5.write(listToStr)
output_file_5.close()
##################################################################################
# FOR 1-D CONV####################################################################
#pointer_index = i_rows*i_cols*i_chans
#one_d_stream = one_d_gen(input_tensor, i_rows, i_cols, i_chans)
#####################################################################################
one_d_stream_2 = one_d_gen(input_tensor, i_rows, i_cols, i_chans)


# get the pointers from end of one_d_stream of data and store in pointers list


# pop kernels from kernel_one_d_stream
pointer_index = k_rows*k_cols*k_chans
for i in range(pointer_index, len(kernel_one_d_stream)):
    kernel_one_d_stream.pop()
    kernel_one_d_stream2.pop()
    kernel_one_d_stream3.pop()
    kernel_one_d_stream4.pop()

##########################################
# #pickle.dump(one_d_stream, output_file)

y = 0
hexlist_B_no_batch = []
for y in range(len(input_tensor_one_d)):
    hex_value_2 = hex(input_tensor_one_d[y]).split('0x')[1]
    if (len(hex_value_2) == 1):
        hex_value_2 = "0"+hex_value_2
    hexlist_B_no_batch.append(hex_value_2)


listToStr_no_batch = ''
x = 0

for x in range(0, len(hexlist_B_no_batch), 1):
    if ((x+1) % stream_width) == 0:
        listToStr_no_batch = listToStr_no_batch + hexlist_B_no_batch[x] + ' '
    else:
        listToStr_no_batch = listToStr_no_batch + hexlist_B_no_batch[x]




print(f'hexlist_NO_BATCH: {hexlist_B_no_batch}')
# listToStr = ' '.join(map(str, hexlist))
output_file_3.write(listToStr_no_batch)
output_file_3.close()





##########################################

# print 1D Kernel
print(f'1D Kernel: {kernel_one_d_stream}')
print(f"1D Stream : {one_d_stream} \n Pointers : {pointers}")

##############################################################################
i = 0

hexlist3 = [(hex(kernel_one_d_stream[x])) for x in range(len(kernel_one_d_stream))]
print(f"Kernel Hex: {hexlist3}")
for j in range(0, len(kernel_tensor), N):
    for i in range(0, len(kernel_one_d_stream), M):
        for n in range(N):
            for m in range(M):
                name = "pe_{}{}.mem".format(m,n)
                with open(data_folder + name, "a+") as pe:
                    hex_value = hex(kernel_tensor[j+n][i+m]).split('0x')[1]
                    if (len(hex_value) == 1):
                        hex_value = "0" + hex_value
                    hex_value = hex_value + " "
                    pe.write(hex_value)
    '''
            name = "pe_{}1.mem".format(m)
            with open(data_folder + name, "a+") as pe:
                hex_value = hex(kernel_one_d_stream2[i + m]).split('0x')[1]
                if (len(hex_value) == 1):
                    hex_value = "0" + hex_value
                hex_value = hex_value + " "
                pe.write(hex_value)
    
            name = "pe_{}2.mem".format(m)
            with open(data_folder + name, "a+") as pe:
                hex_value = hex(kernel_one_d_stream3[i + m]).split('0x')[1]
                if (len(hex_value) == 1):
                    hex_value = "0" + hex_value
                hex_value = hex_value + " "
                pe.write(hex_value)
    
            name = "pe_{}3.mem".format(m)
            with open(data_folder + name, "a+") as pe:
                hex_value = hex(kernel_one_d_stream4[i + m]).split('0x')[1]
                if (len(hex_value) == 1):
                    hex_value = "0" + hex_value
                hex_value = hex_value + " "
                pe.write(hex_value)
'''



# Begin Fun stuff
# one_d_index keeps a track of the index of the one_d_stream. Possibly the most important variable.
one_d_index = 0
temp_list2 = []
temp_list3 = []
temp_list4 =[]
# convolution_pointers determines the next block to be pointed to.
convolution_pointers = [0] * k_rows
# output_one_d_stream stores the output after multiplication and addition.
output_one_d_stream = []
output_three_d_stream = [[0 for i in range(o_cols)] for j in range(o_rows)]

output_one_d_stream2 = []
output_three_d_stream2 = [[0 for i in range(o_cols)] for j in range(o_rows)]
# outer loop to loop through the output_tensor rows
for o_row in range(o_rows):
    # i determines pointer to pull in terms of of the row of output at this stage, change stride for varying strides.
    i = o_row*stride
    # for loop to assign pointers that will be used in this iteration to convolution_pointers[]
    for pointers_idx in range(k_rows):
        convolution_pointers[pointers_idx] = pointers[i]
        i += 1
    # second outer loop to loop through the columns in output_tensor

    for lm_counter in range(0,LM):
        for o_col in range(o_cols):
            # temp_list is list that stores the values plucked from the 1D stream
            temp_list_index = 0
            temp_list = [0] * (k_cols * k_rows * k_chans)
            temp_list_2 = [0] * (k_cols * k_rows * k_chans)
            # inner loop 1 to loop through the rows in input_tensor corresponding to kernel row length
            for rows in range(k_rows):
                # one_d_index (k_chans * stride) determines the stride, change value of stride to change the stride.
                one_d_index = o_col * (k_chans*stride)
                one_d_index = one_d_index + convolution_pointers[rows]
                print(one_d_index)
                # second inner loop to loop through the (cols*channels) i.e. 1 complete row of the input_tensor
                for cols_chans_index in range((i_chans*k_cols)):
                    temp_list[temp_list_index] = one_d_stream[one_d_index]
                    temp_list_2[temp_list_index] = one_d_stream2[one_d_index]
                    temp_list_index += 1
                    one_d_index += 1
            acc = 0

            acc2 = 0
            for tm_counter in range(TM):
                #acc = 0
                for j in range((k_chans*k_rows*k_cols)):
                    if tm_counter == 0:
                        acc += temp_list[j]*kernel_one_d_stream[j]
                    temp_list4.append(temp_list[j])
                    temp_list2.append(temp_list[j])

                output_one_d_stream.append(acc)
                output_three_d_stream[o_row][o_col] = acc
                for j in range((k_chans*k_rows*k_cols)):
                    if tm_counter == 0:
                        acc2 += temp_list_2[j]*kernel_one_d_stream[j]
                    temp_list2.append(temp_list_2[j])
                output_one_d_stream2.append(acc2)
                output_three_d_stream2[o_row][o_col] = acc2
            print(temp_list)
            print(temp_list_2)
                #temp_list2.append(temp_list)
print(f'temp_list3 : {temp_list4}')
print(f'tempList2: {temp_list2}')
listToStr_output_no_batch = ' '.join(map(str, temp_list4))
print(f'listToStr {listToStr_output_no_batch}')
output_file_8.write(listToStr_output_no_batch)
output_file_8 .close()

hex_list3 = [hex(temp_list2[x]) for x in range(len(temp_list2))]
listToStr3 = ' '.join(map(str, hex_list3))
output_file_4.write(listToStr3)
output_file_4.close()

listToStr2 = ' '.join(map(str, temp_list2))
output_file_2.write(listToStr2)
output_file_2.close()


print(f'\n \n OUTPUT 1D Stream : {output_one_d_stream}')
print(f'\n \n OUTPUT 1D Stream 2 : {output_one_d_stream2}')
print(f'Length of Output Stream : {len(output_one_d_stream)}')
print(f'2D output 1: ')
pprint.pprint(output_three_d_stream)
print(f'2D output 1: ')
pprint.pprint(output_three_d_stream2)

output_tensor = [0] * (o_cols*o_rows)
output_tensor = ndimage.convolve(input_tensor, kernel, mode='constant', cval=0.0)

tor_input = torch.IntTensor(input_tensor)
tor_input_2 = tor_input.unsqueeze(0)
#print(tor_input_2)
tor_kernel = torch.IntTensor(kernel)
tor_kernel2 = tor_kernel.unsqueeze(0)
'''
tor_kernel_1 = torch.IntTensor(kernel2)
tor_kernel2_1 = tor_kernel_1.unsqueeze(0)

tor_kernel_2 = torch.IntTensor(kernel3)
tor_kernel2_2 = tor_kernel_2.unsqueeze(0)

tor_kernel_3 = torch.IntTensor(kernel4)
tor_kernel2_3 = tor_kernel_3.unsqueeze(0)
'''
tor_input2 = torch.IntTensor(input_tensor2)
tor_input2_2 = tor_input2.unsqueeze(0)
output_flatten = []
for oc in range(output_chans):
    tor_kernel_1 = torch.IntTensor(kernel_tensor2[oc])
    tor_kernel2_1 = tor_kernel_1.unsqueeze(0)
    mul3 = torch.nn.functional.conv2d(tor_input_2, tor_kernel2_1, padding=(padding, padding), stride=(stride, stride))
    print(f'for loop conv2d output BATCH1 {oc} : \n{mul3}')
    i = 0
    j = 0
    for i in range(o_dimension):
        for j in range(o_dimension):
            output_flatten.append(mul3[0][0][i][j])
if batch_size > 1:
    for oc in range(output_chans):
        tor_kernel_1 = torch.IntTensor(kernel_tensor2[oc])
        tor_kernel2_1 = tor_kernel_1.unsqueeze(0)
        mul4 = torch.nn.functional.conv2d(tor_input2_2, tor_kernel2_1, padding=(padding, padding), stride=(stride, stride))
        print(f'for loop conv2d output BATCH2 {oc} : \n{mul4}')
        i = 0
        j = 0
        for i in range(o_dimension):
            for j in range(o_dimension):
                output_flatten.append(mul4[0][0][i][j])




output_reshape = []

i = 0
offset = 0
for i in range((o_dimension * o_dimension)):
    for j in range(offset, len(output_flatten), (o_dimension * o_dimension)):
        output_reshape.append(output_flatten[j])
    offset = offset + 1
print(output_flatten)
print(output_reshape)


y = 0
hexlist_batchless_output = []

for y in range(len(output_reshape)):
    hex_value_2 = hex(output_reshape[y]).split('0x')[1]
    if (len(hex_value_2) == (C_width - 1)):
        hex_value_2 = "0"+hex_value_2
    hexlist_batchless_output.append(hex_value_2)


listToStr_batchless_output = ''
x = 0

for x in range(0, len(hexlist_batchless_output), 1):
    if ((x+1) % C_stream_width) == 0:
        listToStr_batchless_output = listToStr_batchless_output + hexlist_batchless_output[x] + ' '
    else:
        listToStr_batchless_output = listToStr_batchless_output + hexlist_batchless_output[x]



output_file_batchless_output = open("convolution_batchless_compare.txt", "w")
print(f'batchless output: {hexlist_batchless_output}')
print(f'batchless output: {listToStr_batchless_output}')
# listToStr = ' '.join(map(str, hexlist))
output_file_batchless_output.write(listToStr_batchless_output)
output_file_batchless_output.close()



print(tor_input_2.size())
print(tor_kernel2.size())
mul1 = torch.nn.functional.conv2d(tor_input_2, tor_kernel2, padding=(padding,padding), stride=(stride,stride))
mul2 = torch.nn.functional.conv2d(tor_input2_2, tor_kernel2, padding=(padding,padding), stride=(stride,stride))
'''
mul3 = torch.nn.functional.conv2d(tor_input_2, tor_kernel2_1, padding=(padding,padding), stride=(stride,stride))
mul4 = torch.nn.functional.conv2d(tor_input_2, tor_kernel2_2, padding=(padding,padding), stride=(stride,stride))
mul5 = torch.nn.functional.conv2d(tor_input_2, tor_kernel2_3, padding=(padding,padding), stride=(stride,stride))
'''


#mul1 = torch.nn.functional.conv2d(tor_input_2, tor_kernel2, padding=(1,1), stride=(stride,stride))
print(f'torch conv2d output :\n{mul1}')
print(f'mul1[0][0] {hex(mul1[0][0][0][0])}')
print(f'mul1[0][1] {mul1[0][0][0][1]}')
print(f'mul1[1][0] {mul1[0][0][1][0]}')
print(f'torch conv2d output 1 batch 2 : \n{mul2}')

'''
print("OUTPUT TENSOR : ")
print(output_tensor)
output_tensor_B = []
output_tensor_B = signal.fftconvolve(input_tensor, kernel, mode='same')
print(f'SECOND ONE: {output_tensor_B}')
'''

'''
Use at later stage : 
# Generate empty 3D matrix for output tensor and then allocate values from 1D stream
converted_tensor = three_d__output_generator(i_z_rows, i_z_cols, i_z_chans)
converted_tensor = one_d_to_three_d_converter(one_d_stream, pointers, i_z_rows, i_z_cols, i_z_chans, converted_tensor)

# print everything
print(f"1D Stream : {one_d_stream} \n Pointers : {pointers} \n Converted 3D matrix : ")
pprint.pprint(converted_tensor)

# check for array equality
array_equality = np.array_equal(zero_padding_input_tensor, converted_tensor)
if array_equality:
    print("Success, the arrays are equal!")
else:
    print("Arrays are not equal")
'''

