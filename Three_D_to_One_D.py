def one_d_gen(input_tensor, i_rows, i_cols, i_chans):
    # one_d_stream stores the 1D data to be streamed
    one_d_stream = []
    pointers = [] * i_rows
    # For loop that fills one_d_stream with 3-D input tensor values. indexing -> [channels][
    for rows in range(i_rows):
        pointers.append(len(one_d_stream))
        for cols in range(i_cols):
            for chans in range(i_chans):
                one_d_stream.append(input_tensor[chans][rows][cols])

   # print(f"Pointers after Conversion: {pointers}")
    one_d_stream.extend(pointers)
    return one_d_stream
