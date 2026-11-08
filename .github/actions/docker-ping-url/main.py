import os
import requests
from time import sleep

def ping_url(url, delay, max_trials):
    delay = int(delay)
    max_trials = int(max_trials)
    for _ in range(max_trials):
        try:
            response = requests.get(url)
            if response.status_code == 200:
                print(f"Website {url} is reachable.")
                return True
        except requests.RequestError:
            print(f"Website {url} is not reachable. Retrying in {delay} seconds...")
            pass
        time.sleep(delay)
        except requests.exceptions.MissingSchema as e:
            print(f"Website {url} is not reachable. Retrying in {delay} seconds...")
            print(f"Make sure the URL is valid.")
            print(f"An error occurred: {e}")
            return False
    return False


def run(){

  websie_url = os.getenv("INPUT_URL")
  delay = os.getenv("INPUT_DELAY")
  max_trials = os.getenv("INPUT_MAX_TRIALS")

  website_reachable = ping_url(website_url, delay, max_trials)

  if not website_reachable:
      print(f"Website {website_url} is not reachable after {max_trials} attempts.")
      exit(1)
    else:
        print(f"Website {website_url} is reachable.")

  print("Hello, Docker!")
}


if __name__ == "__main__":
  run()