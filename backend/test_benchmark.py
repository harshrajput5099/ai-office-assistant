# backend/test_benchmark.py
"""
Benchmark tester for upgraded document processing system.
Tests all file formats and document sizes.
Run: python test_benchmark.py
"""

import requests
import os
import time
import json

BASE_URL = "http://localhost:8000"

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
CYAN   = "\033[96m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def passed(msg): print(f"{GREEN}✅ PASSED{RESET} — {msg}")
def failed(msg): print(f"{RED}❌ FAILED{RESET} — {msg}")
def info(msg):   print(f"{BLUE}ℹ️  {RESET}  {msg}")
def header(msg): print(f"\n{BOLD}{CYAN}{'─'*60}{RESET}\n{BOLD}  {msg}{RESET}\n{CYAN}{'─'*60}{RESET}")


def test_file_format(filepath: str, use_mistral: bool = True):
    """Test a specific file and return benchmark results."""
    filename = os.path.basename(filepath)
    ext = os.path.splitext(filename)[1].upper()

    header(f"Testing: {filename} ({ext})")

    if not os.path.exists(filepath):
        info(f"File not found: {filepath} — skipping")
        return None

    file_size_kb = os.path.getsize(filepath) / 1024
    info(f"File size: {file_size_kb:.1f} KB")

    start = time.time()
    try:
        with open(filepath, "rb") as f:
            mime_types = {
                '.pdf':  'application/pdf',
                '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                '.doc':  'application/msword',
                '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
                '.ppt':  'application/vnd.ms-powerpoint',
                '.txt':  'text/plain',
            }
            ext_lower = os.path.splitext(filename)[1].lower()
            mime = mime_types.get(ext_lower, 'application/octet-stream')

            response = requests.post(
                f"{BASE_URL}/api/summarize-document"
                f"?use_mistral={str(use_mistral).lower()}"
                f"&include_benchmark=true",
                files={"file": (filename, f, mime)},
                timeout=300
            )

        elapsed = round(time.time() - start, 2)

        if response.status_code == 200:
            data = response.json()
            benchmark = data.get("benchmark", {})
            b_file = benchmark.get("file_info", {})
            b_proc = benchmark.get("processing", {})
            b_out  = benchmark.get("output", {})

            passed(f"{ext} processed successfully in {elapsed}s")
            print(f"\n  {BOLD}📄 Document Info:{RESET}")
            print(f"     File size   : {b_file.get('file_size_kb', '?')} KB")
            print(f"     Pages       : {b_file.get('page_count', '?')}")
            print(f"     Words       : {b_file.get('word_count', '?')}")
            print(f"     Est. tokens : {b_file.get('estimated_tokens', '?')}")
            print(f"\n  {BOLD}⚙️  Processing:{RESET}")
            print(f"     Strategy    : {b_proc.get('strategy_used', '?')}")
            print(f"     Model       : {b_proc.get('model_used', '?')}")
            print(f"     Chunks      : {b_proc.get('chunk_count', '?')}")
            print(f"     Extract time: {b_proc.get('extraction_time_s', '?')}s")
            print(f"     Summ. time  : {b_proc.get('summarization_time_s', '?')}s")
            print(f"     Total time  : {b_proc.get('total_time_s', '?')}s")
            print(f"\n  {BOLD}📝 Output:{RESET}")
            print(f"     Summary words : {b_out.get('summary_word_count', '?')}")
            print(f"     Coverage      : {b_out.get('coverage_ratio_percent', '?')}%")
            print(f"     Quality note  : {b_out.get('quality_note', '?')}")
            print(f"\n  {BOLD}Summary preview:{RESET}")
            print(f"  {data['summary'][:300]}...")

            return {
                "file": filename,
                "status": "passed",
                "total_time_s": elapsed,
                "pages": b_file.get('page_count'),
                "words": b_file.get('word_count'),
                "chunks": b_proc.get('chunk_count'),
                "tokens": b_file.get('estimated_tokens'),
                "summary_words": b_out.get('summary_word_count'),
                "coverage_pct": b_out.get('coverage_ratio_percent'),
                "strategy": b_proc.get('strategy_used'),
            }
        else:
            failed(f"Status {response.status_code}: {response.json()}")
            return {"file": filename, "status": "failed", "error": response.json()}

    except requests.exceptions.Timeout:
        failed(f"Timed out after 300s — document may be too large for T5")
        info("Try with use_mistral=True or reduce document size")
        return {"file": filename, "status": "timeout"}
    except Exception as e:
        failed(str(e))
        return {"file": filename, "status": "error", "error": str(e)}


def print_comparison_table(results: list):
    """Print a comparison table of all benchmark results."""
    header("BENCHMARK COMPARISON TABLE")
    print(f"\n  {BOLD}{'File':<25} {'Pages':>6} {'Words':>8} {'Chunks':>7} {'Tokens':>8} {'Time(s)':>8} {'Summary':>8} {'Coverage':>9}{RESET}")
    print(f"  {'─'*25} {'─'*6} {'─'*8} {'─'*7} {'─'*8} {'─'*8} {'─'*8} {'─'*9}")

    for r in results:
        if r and r.get("status") == "passed":
            name = r["file"][:24]
            pages   = str(r.get("pages", "?"))
            words   = str(r.get("words", "?"))
            chunks  = str(r.get("chunks", "?"))
            tokens  = str(r.get("tokens", "?"))
            t       = str(r.get("total_time_s", "?"))
            sumw    = str(r.get("summary_words", "?"))
            cov     = f"{r.get('coverage_pct', '?')}%"
            print(f"  {name:<25} {pages:>6} {words:>8} {chunks:>7} {tokens:>8} {t:>8} {sumw:>8} {cov:>9}")
        elif r:
            name = r.get("file", "?")[:24]
            status = r.get("status", "?").upper()
            print(f"  {name:<25} {RED}{status}{RESET}")


def run_benchmarks():
    print(f"\n{BOLD}{'═'*60}")
    print("   AI OFFICE ASSISTANT — DOCUMENT BENCHMARK SUITE")
    print(f"{'═'*60}{RESET}")

    # Check server
    try:
        r = requests.get(f"{BASE_URL}/", timeout=5)
        assert r.status_code == 200
        print(f"\n{GREEN}✅ Server is running{RESET}")
    except Exception:
        print(f"\n{RED}❌ Server not running — start it first:{RESET}")
        print("   cd backend && venv\\Scripts\\activate")
        print("   python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000")
        return

    print(f"\n{YELLOW}Place test files in your backend/ folder:{RESET}")
    print("  test_small.pdf     (~4 pages)")
    print("  test_medium.pdf    (~40 pages)")
    print("  test_large.pdf     (~400 pages)")
    print("  test_doc.docx      (any Word document)")
    print("  test_ppt.pptx      (any PowerPoint)")
    print("  test_txt.txt       (any text file)")
    print(f"\n{YELLOW}Files not found will be skipped automatically.{RESET}\n")

    test_files = [
        "test_small.pdf",
        "test_medium.pdf",
        "test_large.pdf",
        "test_doc.docx",
        "test_doc.doc",
        "test_ppt.pptx",
        "test_txt.txt",
    ]

    results = []
    for filepath in test_files:
        result = test_file_format(filepath, use_mistral=False)
        if result:
            results.append(result)

    passed_results = [r for r in results if r.get("status") == "passed"]
    if passed_results:
        print_comparison_table(passed_results)

    header("SUMMARY")
    total    = len(results)
    passed_n = len(passed_results)
    failed_n = total - passed_n

    print(f"  {GREEN}Passed : {passed_n}{RESET}")
    print(f"  {RED}Failed : {failed_n}{RESET}")

    if passed_n > 0:
        avg_time = sum(r.get("total_time_s", 0) for r in passed_results) / passed_n
        print(f"  Avg processing time: {round(avg_time, 2)}s")

    print()

    if passed_n == total and total > 0:
        print(f"{GREEN}{BOLD}  🎉 All formats working! System upgrade complete.{RESET}\n")
    elif passed_n > 0:
        print(f"{YELLOW}{BOLD}  ⚠️  Some formats working. Add more test files to verify all.{RESET}\n")
    else:
        print(f"{RED}{BOLD}  ❌ No test files found. Add files and rerun.{RESET}\n")


if __name__ == "__main__":
    run_benchmarks()