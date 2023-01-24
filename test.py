from datetime import datetime
with open("_test.csv", "w") as fp:
    fp.write(str(datetime.now()))