from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db
from routers import auth, history, settings_router, pipeline
from routers import summarize, meeting, email_gen, export


app = FastAPI(title='AI Office Assistant API', version='1.0.0')

@app.on_event('startup')
def startup():
    init_db()   # creates app.db and tables if not exists

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(summarize.router,       prefix='/api', tags=['Summarization'])
app.include_router(meeting.router,         prefix='/api', tags=['Meeting'])
app.include_router(email_gen.router,       prefix='/api', tags=['Email'])
app.include_router(export.router,          prefix='/api', tags=['Export'])
app.include_router(auth.router,            prefix='/api', tags=['Auth'])
app.include_router(history.router,         prefix='/api', tags=['History'])
app.include_router(settings_router.router, prefix='/api', tags=['Settings'])
app.include_router(pipeline.router,        prefix='/api', tags=['Pipeline'])


@app.get('/')
def health_check():
    return {'status': 'AI Office Assistant API is running'}

@app.get('/health')
def health():
    return {'status': 'ok'}