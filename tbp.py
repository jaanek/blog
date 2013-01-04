#!/usr/bin/env python

##############################################################################
#
# tbp.py - Generate a list of top blog posts that can be used in my web site.
#
# Use the Google analytics API to grab my most popular posts over the last
# 30 days and use them to build an HTML list. 
# 
# Requirements:
#   
#   * python-googleanalytics
#     * https://github.com/clintecker/python-googleanalytics
#   * A Google Analytics account
#   * A ~/.pythongoogleanalytics file
#     * See https://github.com/clintecker/python-googleanalytics/blob/master/USAGE.md
#
#
# NOTE: Please note that this is a *very* naive, buggy script that works really
#       well for me but it is alpha quality at best for others. The good news
#       is that it's also very simple, so you should be able to fix any errors.
##############################################################################

from googleanalytics import Connection
import datetime, sys, os

### Log in and grab your account
connection = Connection()

# I only have one account, so that's all I care about
account = connection.get_accounts()[0]

### Determine date range - last 30 days
now = datetime.date.today()
diff = datetime.timedelta(days=30)
startdate = now - diff

#### Grab your data

data = account.get_data(startdate, now, metrics=['pageviews'],
    dimensions=['pagePath','pageTitle'], sort=['pageviews',])

# Reverse because you want it in descending order
page_list = data.list
page_list.reverse()

### Build your list
out_file_path = "%s/source/_includes/custom/asides/most_popular.html" % (os.getcwd())
OUT = open(out_file_path, "w")

# For now, let's just write this to STDOUT

OUT.write("<section>\n")
OUT.write("<h1>Most Popular</h1>\n")
OUT.write("<ul>\n")

# Should print 9 posts since the "/" home page is proababl in your top 10
for page in page_list[0:10]:
    # Skip the home page
    if page[0][0] != "/":
        OUT.write("    <li><a href=\"%s\">%s</a></li>\n" % (page[0][0], page[0][1]))

OUT.write("</ul>\n")
OUT.write("</section>\n")

OUT.close()
