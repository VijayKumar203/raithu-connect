require("dotenv").config();const express=require("express"),http=require("http"),cors=require("cors"),{Server}=require("socket.io"),jwt=require("jsonwebtoken"),db=require("./config/db");
const app=express(),server=http.createServer(app);const origin=(process.env.FRONTEND_ORIGIN||"").split(",").map(x=>x.trim());
app.use(cors({origin:origin.length?origin:true}));app.use(express.json({limit:"1mb"}));
app.get("/health",async(req,res)=>{try{await db.query("SELECT 1");res.json({status:"ok",database:"connected"})}catch(e){res.status(503).json({status:"error",database:"disconnected"})}});
app.use("/api/auth",require("./routes/auth"));app.use("/api/products",require("./routes/products"));app.use("/api/orders",require("./routes/orders"));
const io=new Server(server,{cors:{origin:origin.length?origin:true}});
io.use((socket,next)=>{try{socket.user=jwt.verify(socket.handshake.auth.token,process.env.JWT_SECRET);next()}catch(e){next(new Error("Unauthorized"))}});
io.on("connection",socket=>{socket.join("general");socket.on("chat:message",async({room="general",message})=>{if(typeof message!=="string"||!message.trim()||message.length>2000)return;const safeRoom=String(room).slice(0,80);try{await db.query("INSERT INTO messages(sender_id,room,message) VALUES($1,$2,$3)",[socket.user.id,safeRoom,message.trim()]);io.to(safeRoom).emit("chat:message",{sender_name:socket.user.name,message:message.trim()})}catch(e){socket.emit("chat:error","Message could not be saved")}})});
const port=process.env.PORT||4000;server.listen(port,"0.0.0.0",()=>console.log(`Raithu-Connect API listening on ${port}`));