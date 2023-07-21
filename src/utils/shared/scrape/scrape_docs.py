#!/usr/bin/env python3

import requests
from bs4 import BeautifulSoup
import re

import argparse
import sys

# Create the argument parser
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--url', help='URL argument')

# Parse the command-line arguments
args = parser.parse_args()

# Check if the url argument is provided
if args.url is None:
    # Display an error message and exit
    print('Please provide a URL argument using -u or --url.')
    sys.exit(1)

# Continue with rest of the script
print(f'URL: {args.url}')
# ... perform further actions with the provided URL

# Fetch the web page
response = requests.get(args.url)
html_content = response.text

# Parse the HTML content
soup = BeautifulSoup(html_content, "html.parser")

# Find all the links in the page
links = soup.find_all("a")

# Scrape the text from each linked page
output_text = ""

prefix_counts = {}

for link in links:
    classes = link.get("class")
    if classes is not None and all(elem in classes for elem in ['reference', 'internal']):
        href = link.get("href")
        if href.startswith("http"):  # Skip external links
            continue

        link_url = f"{url}/{href}" if not href.startswith("/") else f"{url}{href}"
        link_response = requests.get(link_url)
        link_content = link_response.text

        link_soup = BeautifulSoup(link_content, "html.parser")
        link_text = re.sub(r'\n+', '\n', link_soup.get_text())
        
        href_no_html = href.replace(".html", "")
        href_split = re.split(r'[\/#]', href_no_html)

        print(f'\n\n\n--- File: {href_split} ---\n')
        print(link_text)

        choice = input(f"Do you want to keep the file for '{href_split}'? (y/n): ")
        if choice.lower() == 'y':
            if href_split[0] in prefix_counts:
                prefix_counts[href_split[0]] += 1
            else:
                prefix_counts[href_split[0]] = 0
            
            href_joined = f"{href_split[0]}-{prefix_counts[href_split[0]]}"

            if (len(href_split) > 1):
                href_joined += '.' + '.'.join(href_split[1:])

            filename = f"{href_joined}.md"
            
            with open(f"{filename}", "w", encoding="utf-8") as file:
                file.write(f"Page: {link_url}\n{link_text}\n\n")

# TODO: feed into TTS