import mysql.connector
from urllib.parse import urlparse
from os import getenv
from dotenv import load_dotenv

load_dotenv() 


class SqlOnline:

    @staticmethod
    def _connect():
        url = urlparse(getenv("DB_URL"))
        try:
            conn = mysql.connector.connect(
                host=url.hostname,
                port=url.port if url.port else 3307,
                user=url.username,
                password=url.password,
                database=url.path.lstrip('/') 
            )

            curs = conn.cursor()

            #query = "CREATE TABLE IF NOT EXISTS filessio (public_url VARCHAR(100))"
            #curs.execute(query)

            return conn, curs
        
        except:
            return None,None
    
    @staticmethod
    def _close(conn,curs):
        if curs:
            curs.close()
        if conn:
            conn.close()
    
    def execute(self, query):
        try:
            conn,curs = self._connect()
            if not conn or not curs:
                return False
            
            curs.execute(query)
            conn.commit()
            return True
        except:
            return False
        finally:
            self._close(conn,curs)

    
    def update_url(self,url:str)->bool:
        try:
            conn,curs = self._connect()
            if not conn or not curs:
                return False
            
            query = f"UPDATE filessio SET public_url='{url}'"
            curs.execute(query)

            if curs.rowcount==0: # no values init
                query = f"INSERT INTO filessio VALUES ('{url}')"
                curs.execute(query)


            conn.commit()
            return True
        except Exception as e:
            print(e)
            return False
        finally:
            self._close(conn,curs)


    def get_url(self)->str:
        conn,curs = self._connect()
        try:
            conn,curs = self._connect()
            if not conn or not curs:
                return False
            query = "SELECT public_url from filessio"
            curs.execute(query)
            url = curs.fetchone()[0]
            return url
        except:
            return ""
        finally:
            self._close(conn,curs)

