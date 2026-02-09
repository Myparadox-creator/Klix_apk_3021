
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import logging
from datetime import datetime

# Import internal modules
from config import get_config, Config, ModelProvider
from mem_0 import get_memory_service, MemoryService
from llm_client import get_client, Message, LLMClient

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Klix RAG Backend")

# Add CORS middleware to allow frontend requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods (GET, POST, OPTIONS, etc.)
    allow_headers=["*"],  # Allow all headers
)

# Global instances
config: Config = get_config()
memory_service: MemoryService = None
llm_client: LLMClient = None

class ChatRequest(BaseModel):
    message: str
    user_id: str = "default_user"
    stream: bool = False

class ChatResponse(BaseModel):
    response: str
    tool_calls: List[Dict[str, Any]] = []

@app.on_event("startup")
async def startup_event():
    global memory_service, llm_client
    logger.info("Starting up Klix Backend...")
    
    # Initialize config
    config.default_provider = ModelProvider.OLLAMA # Default to local for now, easier to test
    # If user wants Gemini, they can set env vars, or we can switch here if keys are present
    if config.google_api_key:
         config.default_provider = ModelProvider.GEMINI

    # Initialize Memory Service
    memory_service = get_memory_service(config)
    
    # Initialize LLM Client
    llm_client = get_client(config=config)
    logger.info(f"Initialized with Provider: {config.default_provider.value}, Memory Enabled: {memory_service.is_enabled}")

@app.on_event("shutdown")
async def shutdown_event():
    if llm_client:
        await llm_client.close()
    if memory_service:
        await memory_service.close()

async def store_memory_task(user_input: str, assistant_response: str, user_id: str):
    """Background task to store memory after response is sent"""
    if memory_service and memory_service.is_enabled:
        try:
            memory_service.extract_and_store(
                user_input=user_input,
                assistant_response=assistant_response,
                user_id=user_id
            )
            logger.info(f"Stored memory for user {user_id}")
        except Exception as e:
            logger.error(f"Failed to store memory: {e}")

@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest, background_tasks: BackgroundTasks):
    try:
        user_input = request.message
        user_id = request.user_id
        
        # 1. Retrieve Memory Context
        memory_context = ""
        if memory_service.is_enabled:
            memory_context = memory_service.get_memory_context(
                query=user_input,
                user_id=user_id,
                max_memories=5
            )
            logger.info(f"Retrieved context length: {len(memory_context)}")

        # 2. Build Messages
        # System message with context
        system_content = llm_client.system_instruction
        if memory_context:
            system_content += f"\n\n## Your Memories About This User:\n{memory_context}\n\nUse these memories to provide personalized, context-aware assistance."
        
        messages = [
            Message(role="system", content=system_content),
            Message(role="user", content=user_input)
        ]

        # 3. Call LLM
        # For simplicity in this v1, we aren't doing the full tool loop or sliding window history here yet
        # We are doing a stateless request-response augmented by RAG
        # To support multi-turn conversation within a session, we'd need to pass history or manage it here.
        # For RAG "past decisions", strictly speaking, we just need the retrieved context.
        # But let's pass a slightly better structure if possible.
        
        response = await llm_client.chat(messages, stream=False)
        
        # 4. Schedule Memory Storage
        background_tasks.add_task(store_memory_task, user_input, response.content, user_id)
        
        return ChatResponse(
            response=response.content,
            tool_calls=response.tool_calls
        )

    except Exception as e:
        logger.error(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
def health_check():
    return {"status": "ok", "memory_enabled": memory_service.is_enabled if memory_service else False}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
