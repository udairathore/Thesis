import filecmp
if filecmp.cmp("OUTPUT_COMPARE.txt", "OUTPUT.txt", shallow=False):
    print("Files are same")
else:
    print("Not same :(")
