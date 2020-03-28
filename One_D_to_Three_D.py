from pprint import pprint


def one_d_to_three_d_converter(one_d_stream, pointers, o_rows,o_cols, o_chans, output_tensor):
    i = 0
    for rows in range(o_rows):
        for cols in range(o_cols):
            for chans in range(o_chans):
                if i < len(one_d_stream):
                    output_tensor[chans][rows][cols] = one_d_stream[i]
                    i += 1

    return output_tensor
