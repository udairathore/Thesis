def zero_padding(input_tensor, i_rows, i_cols, i_chans):
    z_rows = i_rows + 2
    z_cols = i_cols + 2
    z_chans = i_chans
    # zero_padded_input_tensor_channels is an empty list for the output tensor to be generated
    zero_padded_input_tensor_channels = []
    # For loop that fills output_tensor_channels with 0's.
    # Fill column first, append columns to rows, append rows(with columns in them) to channels
    for chans in range(z_chans):
        zero_padded_input_tensor_rows = []
        for rows in range(z_rows):
            zero_padded_input_tensor_columns = []
            for cols in range(z_cols):
                zero_padded_input_tensor_columns.append(0)
            zero_padded_input_tensor_rows.append(zero_padded_input_tensor_columns)
        zero_padded_input_tensor_channels.append(zero_padded_input_tensor_rows)

    for rows in range(1, z_rows-1):
        for cols in range(1, z_cols-1):
            for chans in range(z_chans):
                zero_padded_input_tensor_channels[chans][rows][cols] = input_tensor[chans][rows-1][cols-1]

    return zero_padded_input_tensor_channels