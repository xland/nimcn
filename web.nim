import ueditor,jester, asyncdispatch, htmlgen, db_sqlite,encodings,strutils,json

var ArticleCount = 0
var PageSize = 30

proc InitWeb() = 
    var conn = db_sqlite.open("db.db","","","")
    ArticleCount = db_sqlite.getValue(conn,sql("select count(*) from Article")).parseInt
    db_sqlite.close(conn)

routes:  
  get "/GetArticleList/?@StartRow?":
    var startRow = 0
    if @"StartRow".len > 0 :
        startRow = @"StartRow".parseInt
    var sqlStr = "select RowID,article_title,article_summary from Article order by RowID desc limit "& $(startRow) &","& $PageSize
    var conn = db_sqlite.open("db.db","","","")
    var rows = db_sqlite.getAllRows(conn,sql(sqlStr))
    db_sqlite.close(conn)
    var jrs = json.newJArray()
    for i in 0 .. rows.len-1:
        var obj = %*
            {
                "article_id": rows[i][0],
                "article_title": rows[i][1],
                "article_summary": rows[i][2]
            }
        json.add(jrs,obj)
    
    var data = %*
        {
            "ArticleCount": $(ArticleCount),
            "StartRow": $(startRow),
            "PageSize": $(PageSize)
        }
    json.add(data,"Rows",jrs)
    var str = $(data)
    resp str
  
  get "/GetArticle/?@ID?":
    var ID = 0
    if @"ID".len > 0 :
        ID = @"ID".parseInt
    #todo:sql_injection
    var sqlStr = "select article_title,article_content from Article where RowID = "& $ID    
    var conn = db_sqlite.open("db.db","","","")
    var row = db_sqlite.getRow(conn,sql(sqlStr))
    db_sqlite.close(conn)
    var obj = %*
        {
            "article_title": row[0],
            "article_content": row[1]
        }
    var str = $(obj)
    resp str
  post "/AddArticle":
    var title = request.params["title"]
    var summary = request.params["summary"]
    var content = request.params["content"]
    var sqlStr = sql"insert into Article (article_title,article_summary,article_content) values (?,?,?)"
    var conn = db_sqlite.open("db.db","","","")
    db_sqlite.exec(conn,sqlStr,title,summary,content)
    db_sqlite.close(conn)
    resp "true"


  get "/ueditor/ueditor.handler":
    resp ueditor.GetParamRoutes(request)
    
  post "/ueditor/ueditor.handler":
    resp ueditor.PostParamRoutes(request)
    
InitWeb()
runForever()