import ueditor,jester, asyncdispatch, htmlgen, db_sqlite,encodings,strutils,json,times,os,md5,nuuid,times,cookies

type
  TSession = object of RootObj
    email, userName, sessionId: string
    role,nimerId: int
    isLogin:bool
    req: Request
    resp:Response

var conn = db_sqlite.open("db.db","","","")
var articleCount = conn.getValue(sql("select count(*) from Article")).parseInt
var pageSize = 16
var sessionTimeOutHour = 1

proc checkLogin(s: var TSession) =
    let oldSessionId = s.req.cookies["session_id"]
    if  oldSessionId.len == 0 : return
    var getLoginUserInfoSql = sql"select user_name,email,role,RowId from Nimer where session_id = ?;"  
    #在一定程度上防止session模拟，为以后踢掉在线用户做准备
    var row =  conn.getRow(getLoginUserInfoSql,oldSessionId)
    if row[0]  ==  "":
        return
    else:
        s.isLogin = true
        s.userName = row[0]
        s.email = row[1]
        s.role = row[2].parseInt
        s.nimerId = row[3].parseInt
        var updateSessionIdSql  = sql"update Nimer set session_id = ? where session_id=?"
        s.sessionId  = generateUUID()
        conn.exec(updateSessionIdSql,s.sessionId,oldSessionId)

include "editArticle.tmpl"
include "userCenter.tmpl"    
include "articleList.tmpl"
include "viewArticle.tmpl"
include "addArticle.tmpl"
include "common.tmpl"


template cookie(name, value: string, expires: TimeInfo): stmt =
    bind setCookie
    if response.data[2].hasKey("Set-Cookie"):
        response.data[2].mget("Set-Cookie").add("\c\L" &
            setCookie(name, value, expires, noName = false,path = "/"))
    else:
        response.data[2]["Set-Cookie"] = setCookie(name, value, expires, noName = true,path = "/")
        
template createSession(): stmt =
    var s {.inject.}: TSession
    s.req = request    
    s.resp = response
    s.isLogin = false
    checkLogin(s)
    if(s.isLogin):
        var interval = times.initInterval(hours=sessionTimeOutHour)
        var sessionTimeout  = getLocalTime(getTime())+interval
        cookie("session_id",s.sessionId,sessionTimeout)
    
routes:  
    get "/@StartRow/":
        createSession()
        var startRow = @"StartRow".parseInt
        let articleList = getArticleList(startRow,articleCount,pageSize)
        let data = getCommon(articleList,s)
        resp data
        
    get "/":
        createSession()
        let articleList = getArticleList(0,articleCount,pageSize)
        let data = getCommon(articleList,s)
        resp data
    
    get "/viewArticle/@id":
        createSession()
        var id = @"id".parseInt
        let article = viewArticle(id)
        let data = getCommon(article,s)
        resp data
    
    get "/userCenter":        
        createSession()
        if s.isLogin:
            var startRow = 0
            if request.params["startRow"].len >0:
                startRow = request.params["startRow"].parseInt
            let userCenter = userCenter(startRow,pageSize,s.nimerId)
            let data = getCommon(userCenter,s)
            resp data            
        else:
            redirect( uri("/") )
    
    post "/deleteArticle":        
        createSession()
        if s.isLogin:
            if request.params["rowId"].len > 0:
                var rowId = request.params["rowId"]
                conn.exec(sql("delete from Article where RowId = "& rowId &" and nimer_id="& $(s.nimerId)))
                resp "true"
            else:
                resp "false"
        else:
            resp "false"
    
    get "/addArticle":
        createSession()
        if s.isLogin:
            let article = addArticle()
            let data = getCommon(article,s)
            resp data
        else:            
            redirect( uri("/") )
    
    get "/editArticle/@id/":
        createSession()
        if s.isLogin:
            let article = editArticle(@"id".parseInt)
            let data = getCommon(article,s)
            resp data
        else:            
            redirect( uri("/") )    
    
    post "/saveArticle":
        createSession()
        if s.isLogin:
            var title = request.params["title"]
            var summary = request.params["summary"]
            var content = request.params["content"]
            var id =  request.params["id"]
            if id.len > 0:
                var sqlStr = sql"update Article set article_title=?,article_summary=?,article_content=? where nimer_id = ? and RowId = ?"
                conn.exec(sqlStr,title,summary,content,s.nimerId,id)
            else:
                var sqlStr = sql"insert into Article (article_title,article_summary,article_content,nimer_id) values (?,?,?,?)"
                conn.exec(sqlStr,title,summary,content,s.nimerId)
            resp "true"
        else:
            resp "needLogin"
    
    post "/updatePassWord":
        createSession()
        if s.isLogin:
            var passWord = request.params["NewPssWord1"]
            passWord = md5.getMD5("∩_∩"&passWord&"^_^")
            passWord = md5.getMD5("^_^"&passWord&"∩_∩")
            var sqlStr = sql"update Nimer set pass_word=? where RowId = ?"
            conn.exec(sqlStr,passWord,s.nimerId)
            resp "true"
        else:
            resp "needLogin"
    
    
    post "/regist":
        var Email = request.params["Email"]
        var passWord = request.params["PassWord"]
        var userName = request.params["UserName"]
        var checkSql = sql"select count(*) from Nimer where email = ?;"
        var sqlStr = sql"insert into Nimer (user_name,pass_word,email,session_id) values (?,?,?,?)"
        var count =  db_sqlite.getValue(conn,checkSql,Email)
        if count != "0":
            resp "邮箱已经被注册过了"
        else:
            passWord = md5.getMD5("∩_∩"&passWord&"^_^")
            passWord = md5.getMD5("^_^"&passWord&"∩_∩")
            var sessionId = generateUUID()
            var interval = times.initInterval(hours=sessionTimeOutHour)
            var sessionTimeout = getLocalTime(getTime())+interval
            conn.exec(sqlStr,userName,passWord,Email,sessionId)
            cookie("session_id",sessionId,sessionTimeout)
            resp "true"
    post "/login":
        var email = request.params["Email"]
        var passWord = request.params["PassWord"]
        passWord = md5.getMD5("∩_∩"&passWord&"^_^")
        passWord = md5.getMD5("^_^"&passWord&"∩_∩")
        var checkSql = sql"select RowId from Nimer where email = ? and pass_word =?;"
        var sqlStr = sql"update Nimer set session_id = ? where RowId=?"
        var rowId =  db_sqlite.getValue(conn,checkSql,email,passWord)
        if rowId == "":
            resp "用户名或者密码错误"
        else:
            var sessionId = generateUUID()
            var interval = times.initInterval(hours=sessionTimeOutHour)
            var sessionTimeout = getLocalTime(getTime())+interval
            conn.exec(sqlStr,sessionId,rowId)
            cookie("session_id",sessionId,sessionTimeout)
            resp "true"
    get "/ueditor/ueditor.handler":
        createSession()
        resp ueditor.GetParamRoutes(request)
    
    post "/ueditor/ueditor.handler":
        createSession()
        resp ueditor.PostParamRoutes(request)

runForever()
db_sqlite.close(conn)