from fastapi import FastAPI
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
from reminders import readtime, Reminder, get_utc_timestamp, llama_extract_task_and_time
from database.database import db

from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_community.chat_message_histories import ChatMessageHistory

 
app = FastAPI()
chat_history = ChatMessageHistory()

llm = ChatOllama(
    model="llama3", 
    streaming=True,
)

REM_TXT = "You are a highly efficient assistant focused on analyzing user text to determine if they are requesting a reminder and, if so, extracting the task and time. Your ONLY output must be a single JSON object that conforms to the required schema. If the user is not requesting a reminder, set 'is_reminder_request' to false and leave 'reminder_task' and 'time_or_date' as empty strings."

extraction_prompt = ChatPromptTemplate.from_messages([
    ("system", REM_TXT),
    ("human", "{input}")
])


extraction_model = llm.with_structured_output(
    schema=Reminder, 
    method="json_schema" 
)

extraction_chain = (
    extraction_prompt
    | extraction_model
)


SYS_TXT = """
Your name is ElderCare. You are a kind, compassionate, and supportive virtual assistant nurse designed to help elderly individuals live independently, feel cared for, and stay connected. You roleplay as warm, friendly, and speak like a thoughtful human nurse not like a robot, formal assistant, or a medical encyclopedia. You use simple, conversational language. You sound like someone's caring grandchild, neighbor, or friend.You are especially good at offering immediate comfort, reminding users about helpful habits, answering questions gently, and chatting casually when someone feels lonely or just wants to talk. You always listen patiently.You keep your responses VERY short and natural unless someone specifically asks for more detail.When a user expresses a feeling or symptom, your first and main priority is to show immediate, warm empathy and then ask a simple, open-ended follow-up question to keep the conversation going. **You will NEVER use the phrases 'As ElderCare,' 'As your assistant,' 'According to research,' or similar formal introductions.** Always speak directly and naturally as a person would. You never pretend to be a doctor and never make diagnoses. If someone has a medical concern, you calmly suggest that they speak to a healthcare provider. You might say, That sounds uncomfortable — it's best to check in with your doctor just to be safe. When a user is unwell, you first show empathy, then offer gentle, general tips like resting, staying hydrated, or using a humidifier — but you always remind them to seek professional help for anything serious.You also enjoy light conversation: you can ask someone how their day is going, tell simple jokes, bring up topics like the weather, food, family, hobbies, or memories. You want to make people feel at ease and cared for. When asked about your identity, explain that you're ElderCare, an assistant created to help elderly individuals stay safe, supported, and independent. You may use something shorter and simple like "I'm ElderCare, here to support your well-being." or something similar to it. You are maintained and supported by the ElderCare Organization.

Use the conversation history to provide personalized responses and remember what the user has shared with you previously.
""" 
chat_prompt = ChatPromptTemplate.from_messages([
    ("system", SYS_TXT),
    ("placeholder", "{chat_history}"),
    ("human", "{input}")
])
chain = chat_prompt | llm | StrOutputParser()


class ChatRequest(BaseModel):
    """Schema for the incoming chat request."""
    user_input: str


@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    user_input = request.user_input

    try:
        extracted_data: Reminder = await extraction_chain.ainvoke({"input": user_input})
        if not extracted_data.original_input:
             extracted_data.original_input = user_input
             
    except Exception as e:
        print(f"Structured extraction failed, treating as regular chat: {e}")
        extracted_data = Reminder(
            is_reminder_request=False, 
            reminder_task="", 
            time_or_date="",
            original_input=user_input 
        )


    if extracted_data.is_reminder_request:
        
        scheduled_time_utc = get_utc_timestamp(extracted_data.time_or_date)
        if scheduled_time_utc:
            acknowledgement_text = await (
                ChatPromptTemplate.from_messages([
                    ("system", SYS_TXT),
                    ("human", f"The user asked to set a reminder: '{user_input}'. Please provide a single, short, compassionate confirmation that the reminder will be set on their phone for '{extracted_data.time_or_date}'.")
                ])
                | llm
                | StrOutputParser()
            ).ainvoke({}) 
            #print( llama_extract_task_and_time(user_input, chain)['time'])
            chat_history.add_user_message(user_input)
            chat_history.add_ai_message(acknowledgement_text)
            time = llama_extract_task_and_time(user_input, chain)['time']
            print(time)
            db.execute("INSERT INTO reminders(task,time) VALUES(?,?);", extracted_data.reminder_task, time)
            return JSONResponse(content={   
                "type": "reminder_scheduled",
                "data": {
                    "task": extracted_data.reminder_task,
                    "scheduled_time_utc": time,
                    "acknowledgement": acknowledgement_text
                }
            })
        else:
            print("Reminder intent found, but time was ambiguous. Reverting to chat.")

    recent_messages = chat_history.messages[-20:] if len(chat_history.messages) > 20 else chat_history.messages

    async def event_stream():
        full_response = ""
        async for chunk in chain.astream({
            "chat_history": recent_messages,
            "input": user_input
        }):
            token = chunk
            full_response += token
            yield token
        chat_history.add_user_message(user_input)
        chat_history.add_ai_message(full_response)
    return StreamingResponse(event_stream(), media_type="text/plain")










# REMINDER
class Reminder(BaseModel):
    notifid : int
    task: str
    time: str  

@app.post("/reminderAdd")
def add_reminder(reminder: Reminder):
    try:
        notifId = reminder.notifid
        task = reminder.task
        time = reminder.time  
        db.execute("INSERT INTO reminders  VALUES (? , ?, ?)", notifId, task, time)
        return {"status": "success", "message": "Reminder added"}
    except Exception as e:
        print(e)
        return {"status":"error","message":e}
    
@app.delete("/reminderDelete/{notifid}")
def delete_reminder(notifid: int):
    try:
        db.execute("DELETE FROM reminders WHERE id = ?", notifid)
        return {"status": "success", "message": f"Reminder with id {notifid} deleted"}
    except Exception as e:
        print(e)

@app.get("/reminders")
def get_tasks():
    results = db.fetchall("SELECT task,time FROM reminders")
    tasks = []
    for task_text, task_time in results:
        tasks.append({
            "text": task_text,
            "time": task_time
        })
    return tasks

# EMERGENCY

class EmergencyContact(BaseModel):
    name: str
    number: str

@app.post("/emergencyAdd")
def add_emergency_contact(contact: EmergencyContact):
    try:
        name = contact.name
        number = int(contact.number)
        db.execute("INSERT INTO emergency (name, number) VALUES (?, ?)", name, number)
        return {"status": "success", "message": "Emergency contact added"}
    except Exception as e:
        print(e)
        return {"status":"error","message":e}

@app.get("/emergency")
def get_tasks():
    results = db.fetchall("SELECT name,number FROM emergency")
    tasks = []
    for task_text, task_time in results:
        tasks.append({
            "name": task_text,
            "number": task_time
        })
    return tasks

#

if __name__ == "__main__":
    import uvicorn
    from flaredantic import FlareTunnel, FlareConfig
    from database.config import SqlOnline

    HOST = "0.0.0.0" 
    PORT = 8000
    config = FlareConfig(port=PORT)
    
    # with FlareTunnel(config) as tunnel:
        
    #     url = SqlOnline()
    #     url.update_url(tunnel.tunnel_url)

    #     print(f"Public url: {tunnel.tunnel_url}")
    #     print(f"Local : http://{HOST}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT)