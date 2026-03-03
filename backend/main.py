from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import summarize, meeting, email_gen

app = FastAPI(title='AI Office Assistant API', version='1.0.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)

app.include_router(summarize.router, prefix='/api', tags=['Summarization'])
app.include_router(meeting.router, prefix='/api', tags=['Meeting'])
app.include_router(email_gen.router, prefix='/api', tags=['Email'])

@app.get('/')
def health_check():
    return {'status': 'AI Office Assistant API is running'}

@app.get("/health")
def health():
    return {"status": "ok"}