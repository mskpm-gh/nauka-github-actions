import argparse
import requests
from time import sleep


def set_output(file_path, key, value):
    with open(file_path, "a") as file:
        print(f"{key}={value}", file=file)

def ping_url(url, delay, max_trials):
    delay = int(delay)
    max_trials = int(max_trials)
    for _ in range(max_trials):
        try:
            response = requests.get(url)
            if response.status_code == 200:
                print(f"Website {url} is reachable.")
                return True
        except (requests.exceptions.MissingSchema,
                requests.exceptions.InvalidSchema,
                requests.exceptions.InvalidURL) as e:
            print("Make sure the URL is valid.")
            print(f"An error occurred: {e}")
            return False
        except requests.exceptions.RequestException as e:
            print(f"An error occurred: {e}")
        print(f"Website {url} is not reachable. Retrying in {delay} seconds...")
        sleep(delay)
    return False


def run():
    parser = argparse.ArgumentParser(description="Ping a URL until it is reachable.")
    parser.add_argument("url")
    parser.add_argument("max_trials", type=int)
    parser.add_argument("delay", type=int)
    args = parser.parse_args()
    website_url = args.url
    delay = args.delay
    max_trials = args.max_trials

    website_reachable = ping_url(website_url, delay, max_trials)

    set_output(os.getenv('GITHUB_OUTPUT'), 'url_reachable', website_reachable)

    if not website_reachable:
        print(f"Website {website_url} is not reachable after {max_trials} attempts.")
        raise SystemExit(1)
    else:
        print(f"Website {website_url} is reachable.")

    print("Hello, Docker!")


if __name__ == "__main__":
    run()