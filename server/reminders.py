# Add this to your imports at the top
from pydantic import Field,BaseModel as LCBaseModel
from langchain_core.utils.function_calling import convert_to_openai_function
import dateutil.parser
from typing import Union
from datetime import datetime, timedelta, timezone
import dateparser
import json
import pytz 

# --- NEW: Reminder Schema ---
class Reminder(LCBaseModel):
    """Schema for extracting a reminder request from user input."""
    is_reminder_request: bool = Field(
        description="Set to true if the user's intent is to set a reminder or be reminded of something. Otherwise, set to false."
    )
    reminder_task: str = Field(
        description="The task or item to be reminded of, e.g., 'take my medication' or 'call my son'."
    )
    time_or_date: str = Field(
        description="The time or date for the reminder, e.g., 'at 3 PM', 'tomorrow morning', or 'in two hours'. Always use natural language. If no time is specified, use an empty string."
    )
    original_input: str = Field(
        description="The complete, unedited original user input."
    )

reminder_tool = convert_to_openai_function(Reminder)


# --- NEW: Helper for Time Conversion (Crucial for Flutter) ---
def get_utc_timestamp(time_phrase: str, user_tz: str = 'Asia/Kolkata') -> Union[str, None]:
    if not time_phrase:
        return None

    try:
        local_tz = pytz.timezone(user_tz)
        now_local = datetime.now(local_tz)
        dt_local_naive = dateutil.parser.parse(time_phrase, fuzzy=True, default=now_local.replace(tzinfo=None))
        
        dt_local_aware = local_tz.localize(dt_local_naive, is_dst=None)
        
        dt_utc = dt_local_aware.astimezone(pytz.utc)

        return dt_utc.isoformat().replace('+00:00', 'Z')

    except Exception as e:
        print(f"Error parsing time phrase '{time_phrase}': {e}")
        return None


def llama_extract_task_and_time(message: str, chain) -> dict:
    current_time = datetime.now(timezone.utc)

    prompt = f"""Extract the reminder task and time from the following sentence. 
Return it as a JSON object with two fields: "task" and "time". 
"time" can be a time expression like "in 20 minutes" or "at 3:45PM" or "at 2:13 am". Just return the JSON only. current time is {current_time}.
if its time like 3:06pm something like its refering to IST, change value to UTC before returning.

Sentence: "{message}"

Expected Output:"""

    response = chain.invoke({"input": prompt})
    print("Raw LLM response:", response)

    try:
        extracted = json.loads(response)
        task = extracted["task"]
        time_str = extracted["time"]

        # Parse the time string with dateparser to handle natural language

        parsed_time = dateparser.parse(
            time_str,
            settings={
                'RELATIVE_BASE': current_time,
                'RETURN_AS_TIMEZONE_AWARE': True,
                'TIMEZONE': 'UTC'
            }
        )

        if not parsed_time:
            raise ValueError(f"Could not parse time: {time_str}")

        # Return the task and UTC ISO format
        return {
            "task": task,
            "time": parsed_time.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')  
        }

    except Exception as e:
        print("Error parsing response:", e)
        return {
            "task": None,
            "time": None,
            "error": str(e)
        }
    

def readtime(utc_str):
    utc_dt = datetime.fromisoformat(utc_str.replace("Z", "+00:00"))

    local_dt = utc_dt.astimezone()  

    readable_time = local_dt.strftime("%A, %d %B %Y at %I:%M %p")
    print(readable_time)