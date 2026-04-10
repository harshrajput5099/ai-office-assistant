"""
Test large documents using Mistral.
Run: python test_large_only.py
Make sure Ollama is running: ollama run mistral
"""
import requests
import time
import os

BASE_URL = "http://localhost:8000"
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def test_with_mistral(filepath: str):
    filename = os.path.basename(filepath)
    file_size_kb = os.path.getsize(filepath) / 1024

    print(f"\n{BOLD}{'─'*55}{RESET}")
    print(f"{BOLD}  Testing: {filename}{RESET}")
    print(f"{'─'*55}")
    print(f"{BLUE}ℹ️  File size: {file_size_kb:.1f} KB{RESET}")
    print(f"{YELLOW}⏳ Using Mistral — may take 1-3 minutes for large files...{RESET}")

    # Check Ollama first
    try:
        r = requests.get("http://localhost:11434", timeout=3)
    except Exception:
        print(f"{RED}❌ Ollama not running!{RESET}")
        print(f"   Open a NEW terminal and run: ollama run mistral")
        print(f"   Keep it running, then try again.")
        return

    ext = os.path.splitext(filename)[1].lower()
    mime_types = {
        '.pdf':  'application/pdf',
        '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.txt':  'text/plain',
    }
    mime = mime_types.get(ext, 'application/octet-stream')

    start = time.time()
    try:
        with open(filepath, 'rb') as f:
            response = requests.post(
                f"{BASE_URL}/api/summarize-document"
                f"?use_mistral=true&include_benchmark=true",
                files={"file": (filename, f, mime)},
                timeout=600  # 10 minutes for very large docs
            )

        elapsed = round(time.time() - start, 2)

        if response.status_code == 200:
            data = response.json()
            b = data.get("benchmark", {})
            fi = b.get("file_info", {})
            pr = b.get("processing", {})
            ou = b.get("output", {})

            print(f"\n{GREEN}✅ PASSED — processed in {elapsed}s{RESET}")
            print(f"\n  {BOLD}📄 Document Info:{RESET}")
            print(f"     File size   : {fi.get('file_size_kb')} KB")
            print(f"     Pages       : {fi.get('page_count')}")
            print(f"     Words       : {fi.get('word_count')}")
            print(f"     Est. tokens : {fi.get('estimated_tokens')}")
            print(f"\n  {BOLD}⚙️  Processing:{RESET}")
            print(f"     Strategy    : {pr.get('strategy_used')}")
            print(f"     Model       : {pr.get('model_used')}")
            print(f"     Chunks      : {pr.get('chunk_count')}")
            print(f"     Total time  : {pr.get('total_time_s')}s")
            print(f"\n  {BOLD}📝 Output:{RESET}")
            print(f"     Summary words : {ou.get('summary_word_count')}")
            print(f"     Coverage      : {ou.get('coverage_ratio_percent')}%")
            print(f"     Quality note  : {ou.get('quality_note')}")
            print(f"\n  {BOLD}Full Summary:{RESET}")
            print(f"  {'-'*50}")
            print(f"  {data['summary']}")
            print(f"  {'-'*50}")

        elif response.status_code == 503:
            print(f"{RED}❌ Ollama not running{RESET}")
            print(f"   Run in a new terminal: ollama run mistral")
        else:
            print(f"{RED}❌ Error {response.status_code}: {response.json()}{RESET}")

    except requests.exceptions.Timeout:
        print(f"{RED}❌ Timed out after 600s{RESET}")
        print(f"   Document may be extremely large.")
        print(f"   Try splitting it into smaller parts first.")
    except Exception as e:
        print(f"{RED}❌ Error: {e}{RESET}")


def run():
    print(f"\n{BOLD}{'═'*55}")
    print("   MISTRAL LARGE DOCUMENT TEST")
    print(f"{'═'*55}{RESET}")

    # Check server
    try:
        requests.get(f"{BASE_URL}/", timeout=5)
        print(f"{GREEN}✅ FastAPI server running{RESET}")
    except Exception:
        print(f"{RED}❌ Server not running{RESET}")
        print("   Start: python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000")
        return

    # Test files — edit this list to test specific files
    test_files = [
        "test_large.pdf",
        "test_doc.docx",
        "test_ppt.pptx",
        "test_txt.txt",
    ]

    for filepath in test_files:
        if os.path.exists(filepath):
            test_with_mistral(filepath)
        else:
            print(f"\n{YELLOW}⏭  Skipping {filepath} — not found{RESET}")

    print(f"\n{BOLD}Done!{RESET}\n")


if __name__ == "__main__":
    run()