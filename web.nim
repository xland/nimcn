import ueditor,jester, asyncdispatch, htmlgen, db_sqlite,encodings,strutils,json,times,os

var ArticleCount = 0
var PageSize = 16

proc InitWeb() = 
    var conn = db_sqlite.open("db.db","","","")
    ArticleCount = db_sqlite.getValue(conn,sql("select count(*) from Article")).parseInt
    db_sqlite.close(conn)

include "articleList.tmpl"
include "viewArticle.tmpl"
include "addArticle.tmpl"
include "common.tmpl"

routes:  
  get "/?@StartRow?":
    var startRow = 0
    if @"StartRow".len > 0 :
        startRow = @"StartRow".parseInt
    let articleList = getArticleList(startRow,ArticleCount,PageSize)
    let data = getCommon(articleList)
    resp data
    
  get "/viewArticle/@id":
    var id = @"id".parseInt
    let article = viewArticle(id)
    let data = getCommon(article)
    resp data
    
  get "/addArticle/":
    let article = addArticle()
    echo(article)
    let data = getCommon(article)
    resp data
  
  post "/saveArticle":
    var title = request.params["title"]
    var summary = request.params["summary"]
    var content = request.params["content"]
    var sqlStr = sql"insert into Article (article_title,article_summary,article_content) values (?,?,?)"
    var conn = db_sqlite.open("db.db","","","")
    var id = db_sqlite.insertID(conn,sqlStr,title,summary,content)
    db_sqlite.close(conn)
    resp "true"


  get "/ueditor/ueditor.handler":
    resp ueditor.GetParamRoutes(request)
    
  post "/ueditor/ueditor.handler":
    resp ueditor.PostParamRoutes(request)

    
InitWeb()
runForever()