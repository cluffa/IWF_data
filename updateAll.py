from scrape.scrapeAthletes import updateAthletes
from scrape.scrapeResults import updateResults
from scrape.scrapeEvents import updateEvents

if __name__ == "__main__":
    print("Updating Events...")
    updateEvents()
    print("Updating Results...")
    updateResults()
    print("Updating Athletes...")
    updateAthletes()
    print("Done!")