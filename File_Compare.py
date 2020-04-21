import filecmp
if filecmp.cmp("OUTPUT.txt", "OUTPUT_COMPARE.txt", shallow=False):
    print("Files are same")
else:
    print("Not same :(")
