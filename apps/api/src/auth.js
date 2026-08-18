import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { pool } from './db.js';
const jwtSecret=()=>process.env.JWT_SECRET||'dev-only-change-me';
export async function authenticate(email,password){const [rows]=await pool.execute(`SELECT u.id,u.company_id,u.full_name,u.email,u.password_hash,u.is_active,GROUP_CONCAT(r.code ORDER BY r.code) roles FROM users u LEFT JOIN user_roles ur ON ur.user_id=u.id LEFT JOIN roles r ON r.id=ur.role_id WHERE u.email=? GROUP BY u.id`,[email]);const user=rows[0];if(!user||!user.is_active||!(await bcrypt.compare(password,user.password_hash)))return null;const roles=user.roles?user.roles.split(','):[];const payload={sub:String(user.id),companyId:user.company_id,roles,name:user.full_name,email:user.email};return{token:jwt.sign(payload,jwtSecret(),{expiresIn:'8h',issuer:'tarazpad'}),user:payload}}
export function requireAuth(req,res,next){const v=req.headers.authorization||'';const token=v.startsWith('Bearer ')?v.slice(7):null;if(!token)return res.status(401).json({error:'AUTH_REQUIRED'});try{req.user=jwt.verify(token,jwtSecret(),{issuer:'tarazpad'});next()}catch{res.status(401).json({error:'INVALID_TOKEN'})}}
export function requireRole(...allowed){return(req,res,next)=>{const roles=req.user?.roles||[];if(roles.includes('SUPER_ADMIN')||allowed.some(r=>roles.includes(r)))return next();res.status(403).json({error:'FORBIDDEN'})}}
