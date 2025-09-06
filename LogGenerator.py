import csv
import time
import sys

sourceData = "OnlineRetail.csv"
placeholder = "LastLine.txt"

def GetLineCount():
    with open(sourceData, encoding='latin-1') as f:  # Specify the correct encoding
        for i, l in enumerate(f):
            pass
    return i

def MakeLog(startLine, numLines):
    destData = time.strftime("/var/log/mywebsite/%Y%m%d-%H%M%S.log")
    with open(sourceData, 'r', encoding='latin-1') as csvfile:  # Specify the correct encoding
        with open(destData, 'w', encoding='latin-1') as dstfile:  # Also ensure writing uses correct encoding
            reader = csv.reader(csvfile)
            writer = csv.writer(dstfile)
            next(reader)  # Skip header
            inputRow = 0
            linesWritten = 0
            for row in reader:
                inputRow += 1
                if inputRow > startLine:
                    writer.writerow(row)
                    linesWritten += 1
                    if linesWritten >= numLines:
                        break
            return linesWritten
        
numLines = 100
startLine = 0            
if len(sys.argv) > 1:
    numLines = int(sys.argv[1])
    
try:
    with open(placeholder, 'r') as f:
        for line in f:
             startLine = int(line)
except IOError:
    startLine = 0

print(f"Writing {numLines} lines starting at line {startLine}\n")

totalLinesWritten = 0
linesInFile = GetLineCount()

while totalLinesWritten < numLines:
    linesWritten = MakeLog(startLine, numLines - totalLinesWritten)
    totalLinesWritten += linesWritten
    startLine += linesWritten
    if startLine >= linesInFile:
        startLine = 0
        
print(f"Wrote {totalLinesWritten} lines.\n")
    
with open(placeholder, 'w') as f:
    f.write(str(startLine))
