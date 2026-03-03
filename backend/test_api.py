import requests
import os
import sys

BASE_URL = "http://localhost:8000"

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def passed(msg): print(f"{GREEN}✅ PASSED{RESET} — {msg}")
def failed(msg): print(f"{RED}❌ FAILED{RESET} — {msg}")
def info(msg):   print(f"{BLUE}ℹ️  INFO{RESET}   — {msg}")
def warn(msg):   print(f"{YELLOW}⚠️  WARN{RESET}   — {msg}")
def header(msg): print(f"\n{BOLD}{YELLOW}{'─'*55}{RESET}\n{BOLD}  {msg}{RESET}\n{BOLD}{YELLOW}{'─'*55}{RESET}")

def test_health_check():
    header("TEST 1 — Health Check")
    try:
        r = requests.get(f"{BASE_URL}/", timeout=10)
        assert r.status_code == 200
        assert "status" in r.json()
        passed(f"Server running → {r.json()['status']}")
        return True
    except requests.exceptions.ConnectionError:
        failed("Cannot reach server on port 8000")
        info("Run these commands:")
        print("   cd backend")
        print("   venv\\Scripts\\activate")
        print("   python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000")
        return False
    except Exception as e:
        failed(str(e))
        return False

def test_api_docs():
    header("TEST 2 — API Docs")
    try:
        r = requests.get(f"{BASE_URL}/docs", timeout=60)
        if r.status_code == 200:
            passed("Docs available at http://localhost:8000/docs")
            return True
        else:
            failed(f"Status: {r.status_code}")
            return False
    except Exception as e:
        failed(str(e))
        return False

def test_error_handling():
    header("TEST 3 — Error Handling")
    all_ok = True

    try:
        r = requests.post(
            f"{BASE_URL}/api/summarize-pdf",
            files={"file": ("test.txt", b"hello", "text/plain")},
            timeout=60
        )
        if r.status_code == 400:
            passed("Wrong file type correctly rejected (400)")
        else:
            failed(f"Expected 400 for wrong type, got {r.status_code}")
            all_ok = False
    except Exception as e:
        failed(f"Wrong type test: {e}")
        all_ok = False

    try:
        r = requests.post(
            f"{BASE_URL}/api/summarize-pdf",
            files={"file": ("empty.pdf", b"", "application/pdf")},
            timeout=60
        )
        if r.status_code == 400:
            passed("Empty file correctly rejected (400)")
        else:
            failed(f"Expected 400 for empty file, got {r.status_code}")
            all_ok = False
    except Exception as e:
        failed(f"Empty file test: {e}")
        all_ok = False

    return all_ok

def test_pdf_t5():
    header("TEST 4 — PDF Summarize (T5 Fast)")
    pdf_path = "test_sample.pdf"

    if not os.path.exists(pdf_path):
        warn(f"'{pdf_path}' not found in backend/ folder")
        info("Put any PDF in backend/ folder named test_sample.pdf")
        info("Skipping this test...")
        return None

    try:
        info("Sending to T5... (first run: 1-2 min to load model)")
        with open(pdf_path, "rb") as f:
            r = requests.post(
                f"{BASE_URL}/api/summarize-pdf?use_mistral=false",
                files={"file": ("test_sample.pdf", f, "application/pdf")},
                timeout=180
            )
        if r.status_code == 200:
            data = r.json()
            assert "summary" in data and len(data["summary"]) > 10
            passed("T5 summary generated!")
            info(f"Model     : {data.get('model_used', 't5-small')}")
            info(f"Chunks    : {data.get('chunk_count', 'N/A')}")
            info(f"Preview   : {data['summary'][:200]}...")
            return True
        elif r.status_code == 422:
            warn("PDF appears to be scanned — no extractable text")
            info("Fix: Use a text-based PDF (not a scanned image)")
            return False
        else:
            failed(f"Status {r.status_code}: {r.json()}")
            return False
    except requests.exceptions.Timeout:
        failed("Timed out — model still loading")
        info("Fix: Wait 2 minutes then run test again")
        return False
    except AssertionError:
        failed("Summary empty or too short")
        info("Fix: Open chunker.py and change chunk_size from 600 to 800")
        return False
    except Exception as e:
        failed(str(e))
        return False

def test_pdf_mistral():
    header("TEST 5 — PDF Summarize (Mistral Quality)")
    pdf_path = "test_sample.pdf"

    if not os.path.exists(pdf_path):
        warn("test_sample.pdf not found — skipping")
        return None

    try:
        info("Sending to Mistral via Ollama... (30-60 seconds)")
        with open(pdf_path, "rb") as f:
            r = requests.post(
                f"{BASE_URL}/api/summarize-pdf?use_mistral=true",
                files={"file": ("test_sample.pdf", f, "application/pdf")},
                timeout=120
            )
        if r.status_code == 200:
            data = r.json()
            passed("Mistral summary generated!")
            info(f"Model   : {data.get('model_used', 'mistral')}")
            info(f"Preview : {data['summary'][:200]}...")
            return True
        elif r.status_code == 503:
            failed("Ollama is not running")
            info("Fix: Open a NEW terminal and run: ollama run mistral")
            info("Keep that terminal open, then test again")
            return False
        else:
            failed(f"Status {r.status_code}: {r.json()}")
            return False
    except requests.exceptions.Timeout:
        failed("Mistral timed out")
        info("Fix: Restart Ollama with: ollama run mistral")
        return False
    except Exception as e:
        failed(str(e))
        return False

def test_email_generation():
    header("TEST 6 — Email Generation (Mistral)")
    try:
        payload = {
            "purpose": "Schedule a project review meeting",
            "recipient_role": "Project Manager",
            "tone": "formal",
            "key_points": [
                "Review Q1 progress",
                "Discuss pending deliverables",
                "Plan next sprint"
            ],
            "call_to_action": "Please confirm availability by Thursday"
        }
        info("Generating email via Mistral... (30-60s)")
        r = requests.post(
            f"{BASE_URL}/api/generate-email",
            json=payload,
            timeout=120
        )
        if r.status_code == 200:
            data = r.json()
            assert "email" in data and len(data["email"]) > 20
            passed("Email generated!")
            info(f"Preview:\n\n{data['email'][:400]}...\n")
            return True
        elif r.status_code == 503:
            failed("Ollama not running")
            info("Fix: Run ollama run mistral in a separate terminal")
            return False
        else:
            failed(f"Status {r.status_code}: {r.json()}")
            return False
    except requests.exceptions.Timeout:
        failed("Email generation timed out")
        return False
    except AssertionError:
        failed("Generated email is empty")
        return False
    except Exception as e:
        failed(str(e))
        return False

def run_all():
    print(f"\n{BOLD}{'═'*55}")
    print("   AI OFFICE ASSISTANT — COMPLETE TEST SUITE")
    print(f"{'═'*55}{RESET}")
    print(f"  Server : {BASE_URL}")
    print(f"  Python : {sys.version.split()[0]}\n")

    results = {}

    results["Health Check"] = test_health_check()
    if not results["Health Check"]:
        print(f"\n{RED}{BOLD}  Server is offline. Fix this first.{RESET}\n")
        return

    results["API Docs"]         = test_api_docs()
    results["Error Handling"]   = test_error_handling()
    results["PDF T5"]           = test_pdf_t5()
    results["PDF Mistral"]      = test_pdf_mistral()
    results["Email Generation"] = test_email_generation()

    header("FINAL RESULTS")
    passed_n  = sum(1 for v in results.values() if v is True)
    failed_n  = sum(1 for v in results.values() if v is False)
    skipped_n = sum(1 for v in results.values() if v is None)

    print(f"  {'Test':<22} Result")
    print(f"  {'─'*22} {'─'*10}")
    for name, result in results.items():
        if result is True:   mark = f"{GREEN}✅ PASS{RESET}"
        elif result is False: mark = f"{RED}❌ FAIL{RESET}"
        else:                 mark = f"{YELLOW}⏭  SKIP{RESET}"
        print(f"  {name:<22} {mark}")

    print(f"\n  {GREEN}Passed : {passed_n}{RESET}")
    print(f"  {RED}Failed : {failed_n}{RESET}")
    print(f"  {YELLOW}Skipped: {skipped_n}{RESET}")

    if failed_n == 0:
        print(f"\n{GREEN}{BOLD}  🎉 All tests passed! Backend is fully working.{RESET}\n")
    elif failed_n <= 2:
        print(f"\n{YELLOW}{BOLD}  ⚠️  Almost there — fix the failed tests above.{RESET}\n")
    else:
        print(f"\n{RED}{BOLD}  ❌ Multiple failures — work through each fix above.{RESET}\n")

if __name__ == "__main__":
    run_all()