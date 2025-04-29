#!/usr/bin/env python3

import requests
from bs4 import BeautifulSoup
import os

import argparse
import sys
from urllib.parse import urljoin

# Create the argument parser
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--url', help='URL argument')
OUTPUT_FOLDER = os.path.expanduser('~/tmp/output_html')
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

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

print(links)

# Function to download and save an HTML page
def download_and_save_html(url, output_folder, filename):
    response = requests.get(url)
    response.raise_for_status()  # Ensure we notice bad responses
    with open(os.path.join(output_folder, filename), 'w', encoding='utf-8') as f:
        f.write(response.text)

for link in links:
    if "href" in link.attrs:
        print(link)
        page_url = urljoin(args.url, link['href'])
        page_name = link['href'].split('/')[-1]  # Use the last part of the URL as the filename
        try:
            if (page_url.endswith(".html")):
                print(f'Downloading {page_url} as {page_name}...')
                download_and_save_html(page_url, OUTPUT_FOLDER, page_name)
        except BaseException as e:
            print(f"Failed to scrape {page_url}")
    