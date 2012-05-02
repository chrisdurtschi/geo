import sys
import json
from SimpleCV import *

if (len(sys.argv) != 3):
    print "USAGE: python match.py source_file template_file"
    exit(1)

capture = Image(sys.argv[1])
tag = Image(sys.argv[2])
output = {}

keys = capture.findKeypointMatch(tag)
if keys is not None:
    key = keys[0]
    output['min_rect'] = key.getMinRect()

print(json.dumps(output))
exit()
