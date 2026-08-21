import mysql from 'mysql2/promise';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname=path.dirname(fileURLToPath(import.meta.url));
const rootDir=path.resolve(__dirname,'../../..');
export const pool=mysql.createPool({host:process.env.MYSQL_HOST||'127.0.0.1',port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER||'tarazpad',password:process.env.MYSQL_PASSWORD||'',database:process.env.MYSQL_DATABASE||'tarazpad',waitForConnections:true,connectionLimit:Number(process.env.MYSQL_POOL_SIZE||20),queueLimit:0,decimalNumbers:true,timezone:'Z',dateStrings:['DATE'],charset:'utf8mb4'});
export async function withTransaction(work){const conn=await pool.getConnection();try{await conn.beginTransaction();const result=await work(conn);await conn.commit();return result}catch(error){await conn.rollback();throw error}finally{conn.release()}}
function parseSqlScript(sql){let delimiter=';',buffer='',out=[];for(const raw of String(sql).replace(/\r\n/g,'\n').split('\n')){const line=raw,trim=line.trim(),m=trim.match(/^DELIMITER\s+(.+)$/i);if(m){if(buffer.trim())throw new Error('DELIMITER encountered before previous SQL statement was terminated');delimiter=m[1].trim();continue}buffer+=line+'\n';if(trim.endsWith(delimiter)){const cut=buffer.lastIndexOf(delimiter);const statement=buffer.slice(0,cut).trim();if(statement)out.push(statement);buffer=buffer.slice(cut+delimiter.length).trimStart()}}if(buffer.trim())out.push(buffer.trim());return out}
async function installOptionalHardCloseGuards(conn){
  const guardFile=path.join(rootDir,'installer','windows-server','HardClose-DatabaseGuards.sql');
  try{
    const sql=await fs.readFile(guardFile,'utf8');
    for(const statement of parseSqlScript(sql))await conn.query(statement);
  }catch(error){
    const code=String(error?.code||'');
    const optionalPrivilegeFailure=new Set(['ER_SPECIFIC_ACCESS_DENIED_ERROR','ER_TABLEACCESS_DENIED_ERROR','ER_DBACCESS_DENIED_ERROR','ER_ACCESS_DENIED_ERROR','ER_BINLOG_CREATE_ROUTINE_NEED_SUPER']);
    if(error?.code==='ENOENT'||optionalPrivilegeFailure.has(code)){
      console.warn('Optional database hard-close guards were not installed; application HARD_CLOSED guard remains active.',code||error.code);
      return;
    }
    throw error;
  }
}
export async function migrate(){const conn=await pool.getConnection();try{await conn.query(`CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) PRIMARY KEY,applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci`);const dir=path.join(rootDir,'database');const files=(await fs.readdir(dir)).filter(f=>/^\d+_.*\.sql$/.test(f)).sort();for(const file of files){const [rows]=await conn.execute('SELECT version FROM schema_migrations WHERE version=?',[file]);if(rows.length)continue;const sql=await fs.readFile(path.join(dir,file),'utf8');const statements=parseSqlScript(sql);await conn.beginTransaction();try{for(const statement of statements)await conn.query(statement);await conn.execute('INSERT INTO schema_migrations(version) VALUES (?)',[file]);await conn.commit()}catch(error){await conn.rollback();throw new Error(`Migration ${file} failed: ${error.message}`)}}await installOptionalHardCloseGuards(conn)}finally{conn.release()}}
export async function healthCheck(){const [rows]=await pool.query('SELECT 1 AS ok');return rows[0]?.ok===1}
export { parseSqlScript };