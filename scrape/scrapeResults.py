# This script will scrape https://iwf.sport/results
# for iwf sanctioned event results
# %%
from bs4 import BeautifulSoup
import requests
import pandas as pd
import numpy as np
import os
from csv import reader, writer

# file directory
dir = os.path.dirname(__file__)


# %%
def is_cat(line):
    return (("Men" in line) | ("Women" in line)) & ("kg" in line)


def is_sec(line):
    return line in ["Snatch", "Clean&Jerk", "Total"]


heads = ["Rank:", "Name:", "Nation:", "Born:", "B.weight:", "Group:", "1:", "2:", "3:", "Total:", "Snatch:", "CI&Jerk:"]


def is_head(line):
    return line in heads


def rep_list(x: str, matches: list):
    for match in matches:
        x = x.replace(match, "")
    return x.strip()


def get_text(soup: BeautifulSoup) -> str:
    text = soup.get_text()

    lines = (line.strip() for line in text.splitlines())

    chunks = (phrase.strip() for line in lines for phrase in line.split("  "))

    text = "\n".join(chunk for chunk in chunks if chunk)
    return text


def containsNumber(value) -> bool:
    for character in value:
        if character.isdigit():
            return True
    return False


def scrape_url(event_id: int = 522):
    """scrapes results page

    Args:
        id (int, optional): id of event. Defaults to 522.

    Returns:
        pd.DataFrame: an uncleaned dataframe
            also outputs to csv ./raw_data

    """

    if event_id < 441:
        old_classes = True
    else:
        old_classes = False

    if old_classes:
        url = f"https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_id={event_id}"
    else:
        url = f"https://iwf.sport/results/results-by-events/?event_id={event_id}"

    req = requests.get(url)
    content = req.text.replace("<strike>", "-").replace("</strike>", "")
    soup = BeautifulSoup(content, "html.parser")

    event = soup.find("h2").text

    men = get_text(soup.find("div", {"id": "men_snatchjerk"})).splitlines()
    women = get_text(soup.find("div", {"id": "women_snatchjerk"})).splitlines()

    all = men + women

    df = pd.DataFrame(
        {"rank": [], "name": [], "nation": [], "born": [], "bw": [], "group": [], "lift1": [], "lift2": [], "lift3": [],
         "lift4": [], "cat": [], "sec": []})
    row = []

    for line in all:

        if is_cat(line):
            cat = line.replace(" ", "")
        elif is_sec(line):
            sec = line.replace("&", "")
        elif head := is_head(line):
            col = 1
        else:
            row.append(rep_list(line, head))
            if "Total:" in line:

                while len(row) < 10:  # a
                    row.append(np.nan)

                row.append(cat)
                row.append(sec)
                # print(row)

                df.loc[len(df)] = row
                row = []

    # df["event"] = event
    df["event_id"] = id
    df["old_classes"] = old_classes
    file = f"{dir}/../raw_data/results/" + str(id) + "_" + event.replace(" ", "_").replace("-", "_").replace(",",
                                                                                                             "_").replace(
        "'", "").replace('"', "") + ".csv"
    df.to_csv(file, index=False)

    print("Event ID: " + str(id))
    print("Event: " + event)
    print("Saved To: " + file)
    print("\n")

    return 0


def scrape_pass_errors(event_id) -> int:
    existing_ids = [int(file.split("_")[0]) for file in os.listdir(f"{dir}/../raw_data/results/")]

    if event_id in existing_ids:
        return 1
    else:
        scrape_url(event_id)
        return 0


def updateResults(event_ids) -> None:
    """Updates the raw data results in-line with the events.csv"""
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


if __name__ == "__main__":
    # ids = pd.read_csv(f"{dir}/../raw_data/events.csv")["id"]
    event_ids = fetch_event_ids()
    updateResults(event_ids)
