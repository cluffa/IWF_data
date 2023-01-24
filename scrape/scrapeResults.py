# This script will scrape https://iwf.sport/results
# for iwf sanctioned event results
# %%
from bs4 import BeautifulSoup
import requests
import os
from os.path import join
from csv import reader, writer
from re import sub

# file directory
dir = os.path.dirname(__file__)

def write_to_csv(base_dir, filepath_name, data):
    """Code chunk from OWL / Sport80 API"""
    with open(join(base_dir, f"{filepath_name}.csv"), 'w', encoding='utf-8') as file_boi:
        csv_writer = writer(file_boi)
        csv_writer.writerows(data)

def is_cat(line):
    return (("Men" in line) | ("Women" in line)) & ("kg" in line)


def is_sec(line):
    return line in ["Snatch", "Clean&Jerk", "Total"]


headers = ["Rank:", "Name:", "Nation:", "Born:", "B.weight:", "Group:", "1:", "2:", "3:", "Total:", "Snatch:",
           "CI&Jerk:"]
#  OK, not a great way to do this but if I refactor it any further it'll be a breaking change
csv_headers = ["rank", "name", "nation", "born", "bw", "group", "lift1", "lift2", "lift3", "lift4", "cat", "sec",
               "event_id", "old_classes"]


def is_head(line):
    return line in headers


def rep_list(x: str, matches: list):
    for match in matches:
        x = x.replace(match, "")
    return x.strip()


def get_text(soup: BeautifulSoup) -> str:
    """Soup in, text out."""
    text = soup.get_text()

    lines = (line.strip() for line in text.splitlines())

    chunks = (phrase.strip() for line in lines for phrase in line.split("  "))

    text = "\n".join(chunk for chunk in chunks if chunk)
    return text


def containsNumber(value) -> bool:
    """Is the value a valid number?"""
    for character in value:
        if character.isdigit():
            return True
    return False


def scrape_url(event_id: int) -> None:
    """Scrapes results page

    Args:
        event_id (int): id of event.
    """

    url = f"https://iwf.sport/results/results-by-events/?event_id={event_id}"

    old_bw_class = False
    if event_id < 441:
        # Changeover of BW categories
        old_bw_class = True
        url = f"https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_id={event_id}"

    req = requests.get(url)
    content = req.text.replace("<strike>", "-").replace("</strike>", "")
    soup = BeautifulSoup(content, "html.parser")

    event = soup.find("h2").text

    men = get_text(soup.find("div", {"id": "men_snatchjerk"})).splitlines()
    women = get_text(soup.find("div", {"id": "women_snatchjerk"})).splitlines()

    both_genders = men + women

    row = []
    big_data = []
    for line in both_genders:
        if is_cat(line):
            cat = line.replace(" ", "")
        elif is_sec(line):
            sec = line.replace("&", "")
        elif is_head(line):
            col = 1
        else:
            row.append(rep_list(line, headers))
            if "Total:" in line:

                while len(row) < 10:  # a
                    row.append('---')
                row.extend([cat, sec, event_id, old_bw_class])
                big_data.append(row)
                row = []

    big_data.insert(0, csv_headers)
    filename = f"{event_id}_{gen_filename(event)}"
    write_to_csv(f"{dir}/../raw_data/results/", filename, big_data)

    print(f"Event ID: {event_id}")
    print(f"Event: {event}")
    print(f"Saved To: {filename}.csv\n")


def gen_filename(raw_name: str) -> str:
    """Strips all special characters for saving operations"""
    new_name = sub(r"[^a-zA-Z0-9]", "_", raw_name)
    return new_name


def scrape_pass_errors(event_id) -> int:
    """Checks whether an event is present in the results folder and adds it if required"""
    existing_ids = fetch_result_ids()

    if event_id in existing_ids:
        return 1
    elif event_id not in existing_ids:
        scrape_url(event_id)
        return 0
    else:
        return 2


def updateResults() -> None:
    """Updates the raw data results in-line with the events.csv"""
    event_ids = fetch_event_ids()
    results = list(map(scrape_pass_errors, event_ids))
    print(results.count(0), "events scraped")
    print(results.count(1), "events already scraped")
    print(results.count(2), "events failed to scrape")


def fetch_event_ids() -> list:
    """Checks the events.csv file in raw_data and returns all event IDs"""
    event_ids: list = []
    with open(f"{dir}/../raw_data/events.csv", "r", encoding='utf-8') as results_file:
        csv_read = reader(results_file)
        for lines in csv_read:
            event_ids.append(lines[0])
    event_ids = [int(x) for x in event_ids[1::]]  # I'm lazy but fuck Pandas/Numpy
    return event_ids


def fetch_result_ids() -> list[int]:
    """Split this down into a function instead of a single line as it's not that Pythonic/readable"""
    result_filenames = os.listdir(f"{dir}/../raw_data/results/")
    result_ids = [x.split("_")[0] for x in result_filenames]
    result_ids_as_int = list(map(int, result_ids))
    return result_ids_as_int


if __name__ == "__main__":
    updateResults()
