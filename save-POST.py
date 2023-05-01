#!/usr/bin/env python

# save-POST.py
#
# by Stefan Wuensch, 2018-03-27
#
# 2021-07-12: Added UUID for total unique filenames.
#
# Save HTTP POST data to log files. Data comes from Apache on STDIN, and
# is saved to two log files sequentially: one log file with a consistent name
# and another log file with a unique (time-stamp) name.
#
# See also
# https://stackoverflow.com/questions/464040/how-are-post-and-get-variables-handled-in-python


# MIT License
# 
# Copyright (c) 2023 Stefan Wuensch
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


import sys
import os
import json
import time
import uuid


def main():

    print( "Content-Type: text/plain\n" )

    my_name = os.path.basename( __file__ )
    unique_str = "_" + str( time.time() ) + "_" + str( uuid.uuid4().hex )
    out_file_timestamp = "/home/w/u/wuensch/public_html/tmp/save-POST_incoming/" + my_name + unique_str
    out_file_latest    = "/home/w/u/wuensch/public_html/tmp/save-POST_incoming/" + my_name + "_latest.txt"

    try:
        post_data = sys.stdin.read()
        assert post_data != "", "Did not get form POST data."
    except Exception:
        print( "Error: Did not get form POST data." )
        sys.exit( 1 )

    try:
        # See if it's JSON.
        json_data = json.loads( post_data )
        is_JSON = True
        out_file_timestamp += ".json"
    except Exception:
        is_JSON = False
        out_file_timestamp += ".txt"

    try:
        out_FH_timestamp = open( out_file_timestamp, 'w' )
        out_FH_latest =    open( out_file_latest, 'w' )
    except Exception:
        print( "Error: Could not open output file / files for writing." )
        sys.exit( 1 )

    try:
        # If it's JSON, pretty-print it to the output files.
        # If it's not JSON, just output to the files as-is.
        if is_JSON:
            out_FH_timestamp.write( json.dumps( json_data, sort_keys = True, indent = 4 ) )
            out_FH_latest.write(    json.dumps( json_data, sort_keys = True, indent = 4 ) )
        else:
            out_FH_timestamp.write( post_data )
            out_FH_latest.write(    post_data )
    except Exception as e:
        print( "Error: Could not write to output file / files: %s\n" % e )
        sys.exit( 1 )

    out_FH_timestamp.write( "\n" )
    out_FH_latest.write( "\n" )
    out_FH_timestamp.close()
    out_FH_latest.close()

    print "OK"


if __name__ == '__main__':
    sys.exit( main() )
