import random


def three_d_generator(i_rows, i_cols, i_chans):
    # input_tensor is the list the stores the 3D input tensor
    input_tensor_channels = []
    # For loop that fills input_tensor with random values.
    # Fill column first, append columns to rows, append rows(with columns in them) to channels
    for chans in range(i_chans):
        input_tensor_rows = []
        for rows in range(i_rows):
            input_tensor_columns = []
            for cols in range(i_cols):
                input_tensor_columns.append(random.randint(0, 100))
            input_tensor_rows.append(input_tensor_columns)
        input_tensor_channels.append(input_tensor_rows)
    return input_tensor_channels


def kernel_three_d_generator(i_rows, i_cols, i_chans):
    # input_tensor is the list the stores the 3D input tensor
    input_tensor_channels = []
    # For loop that fills input_tensor with random values.
    # Fill column first, append columns to rows, append rows(with columns in them) to channels
    input_tensor_rows = []
    for rows in range(i_rows):
        input_tensor_columns = []
        for cols in range(i_cols):
            input_tensor_columns.append(random.randint(0, 100))
        input_tensor_rows.append(input_tensor_columns)
    for chans in range(i_chans):
        input_tensor_channels.append(input_tensor_rows)

    return input_tensor_channels, input_tensor_rows

def three_d__output_generator(o_rows, o_cols, o_chans):
    # output_tensor_channels is an empty list for the output tensor to be generated
    output_tensor_channels = []
    # For loop that fills output_tensor_channels with 0's.
    # Fill column first, append columns to rows, append rows(with columns in them) to channels
    for chans in range(o_chans):
        output_tensor_rows = []
        for rows in range(o_rows):
            output_tensor_columns = []
            for cols in range(o_cols):
                output_tensor_columns.append(0)
            output_tensor_rows.append(output_tensor_columns)
        output_tensor_channels.append(output_tensor_rows)
    return output_tensor_channels
