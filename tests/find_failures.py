#!/usr/bin/python3
"""
This python script is for parsing cocotb's result.xml files for failures.

If a failure is found, then return exit code 1
"""
import argparse
import logging
import os
import xml.etree.ElementTree

DEFAULT_XML = "results.xml"
DEFAULT_IGNORE_FAILS = True

logger = logging.getLogger("FailureFinder")
logger.setLevel(logging.WARNING)

def create_argparser():
    parser = argparse.ArgumentParser()
    parser.add_argument("xml_file", default=DEFAULT_XML, nargs="?", \
        help="cocotb results xml file to parse. Default=%s" % (DEFAULT_XML))

    fail_group = parser.add_mutually_exclusive_group()
    fail_group.add_argument("--ignore-fails", dest="ignore_fails", \
        default=DEFAULT_IGNORE_FAILS, action="store_true", \
        help="Do not exit(1) when a sim fail is found")
    fail_group.add_argument("--fast-fail", dest="ignore_fails", \
        default=DEFAULT_IGNORE_FAILS, action="store_false", \
        help="Return exit code 1 on the first simulation failure")

    return parser

def find_failures(xml_file:str, ignore_fails=False):
    """ Find failures within the input xml_file. """
    tree = xml.etree.ElementTree.parse(xml_file)
    root = tree.getroot()
    fails_found = 0
    for i,testsuite in enumerate(root):
        for j,testcase in enumerate(testsuite):
            for fails in testcase:
                if fails.tag == "failure":
                    fail_dict = root[i][j].attrib
                    test_name = fail_dict["name"]
                    sim = fail_dict["classname"]
                    logger.warning("Failure detected in '%s' test of '%s'" % (test_name, sim))
                    fails_found += 1
                    if not ignore_fails:
                        exit(1)
    if not fails_found:
        logger.info("No failures detected")
    exit(0)

def main():
    """ Parse sys.argv and find failures. """
    parser = create_argparser()
    args = parser.parse_args()
    find_failures(os.path.abspath(args.xml_file), ignore_fails=args.ignore_fails)

if __name__ == "__main__":
    logging.basicConfig(format="%(name)s:%(levelname)s:%(message)s")
    main()

