/*****************************************************************************
	Source: uhmc_mp_comorbidity_submit.prg
	Author: Neil Mendoza
	Date: 03/02/2015
	Purpose: Called to commit data from the Co-Morbidity MPage
******************************************************************************/
 
drop program uhmc_mp_comorbidity3_submit:dba go
create program uhmc_mp_comorbidity3_submit:dba
 
prompt
	"Output to File/Printer/MINE = " = "MINE"
	,"Person Id = " = 0.0
	,"Encntr Id = " = 0.0
	,"Prsnl Id = " = 0.0
	,"Computed Co-Morbidities = " = ""
	,"Other Co-Morbidities = " = ""
 
with outdev, personid, encntrid, prsnlid, ccomorb, ocomorb
 
declare CR = c1 with constant(char(13)),protect
declare CURDTTM = dq8 with constant(cnvtdatetime(curdate,curtime3))
declare CURDTTMVC = vc with constant(format(cnvtdatetime(curdate,curtime3),"YYYYMMDDhhmmss;;d"))
declare cnt = i4
declare cnt1 = i4
declare obxcnt = vc
declare patientname = vc
declare providerstr = vc
declare mrn = vc
declare encntr = vc
declare tmpstr = vc
declare tmpfile = vc
declare finalfile = vc
set tmpfile = build("common_data/tmp",CURDTTMVC,".dat")
set finalfile = build("uhmc_mp_abstract_",format(cnvtdatetime(curdate,curtime3),"MMDDhhmmss;;D"),".dat")
 
free record JSON
record JSON
(
	1 data = vc
)
 
free record temp
record temp
(
	1 successful = i2
	1 msg = vc
)
 
free record temp1
record temp1
(
	1 cccnt = i4
	1 cc[*]
		2 comorb = vc
		2 results = vc
	1 occnt = i4
	1 oc[*]
		2 comorb = vc
)
 
set temp->successful = 0
set temp->msg = "Error creating Co-Morbidity HL7."
 
select into "nl:"
from person p, person_alias pa
plan p where p.person_id = cnvtreal($personid)
	and p.active_ind = 1
join pa where pa.person_id = p.person_id
	and pa.alias_pool_cd = 309692.00	;UHMCSB MRN
	and pa.end_effective_dt_tm > cnvtdatetime(curdate,curtime3)
	and pa.beg_effective_dt_tm < cnvtdatetime(curdate,curtime3)
	and pa.active_ind = 1
detail
	patientname = build(p.name_last,"^",p.name_first)
	mrn = trim(pa.alias,3)
with nocounter
 
select into "nl:"
from encntr_alias ea
where ea.encntr_id = cnvtreal($encntrid)
	and ea.encntr_alias_type_cd = 844.00	;ENC NBR
	and ea.end_effective_dt_tm > cnvtdatetime(curdate,curtime3)
	and ea.beg_effective_dt_tm < cnvtdatetime(curdate,curtime3)
	and ea.active_ind = 1
detail
	encntr = trim(ea.alias,3)
with nocounter
 
select into "nl:"
from prsnl p, prsnl_alias pa
plan p where p.person_id = cnvtreal($prsnlid)
	and p.active_ind = 1
join pa where pa.person_id = outerjoin(p.person_id)
	and pa.prsnl_alias_type_cd = outerjoin(852.00)		;ORGANIZATION DOCTOR
	and pa.end_effective_dt_tm > outerjoin(cnvtdatetime(curdate,curtime3))
	and pa.beg_effective_dt_tm < outerjoin(cnvtdatetime(curdate,curtime3))
	and pa.active_ind = outerjoin(1)
detail
	providerstr = build(pa.alias,"^",p.name_last,"^",p.name_first)
with nocounter
 
set cnt = 2
set cnt1 = 0
while (piece($ccomorb,"~",cnt,"NOMORE") != "NOMORE")
	set cnt1 = cnt1 + 1
	set stat = alterlist(temp1->cc,cnt1)
	set temp1->cc[cnt1].comorb = trim(piece(piece($ccomorb,"~",cnt,""),"^",1,""),3)
	set tmpstr = trim(piece(piece($ccomorb,"~",cnt,""),"^",2,""),3)
	set temp1->cc[cnt1].results = substring(2,size(tmpstr),tmpstr)
	set cnt = cnt + 1
endwhile
set temp1->cccnt = cnt1
 
set cnt = 2
set cnt1 = 0
while (piece($ocomorb,"~",cnt,"NOMORE") != "NOMORE")
	set cnt1 = cnt1 + 1
	set stat = alterlist(temp1->oc,cnt1)
	set temp1->oc[cnt1].comorb = trim(piece($ocomorb,"~",cnt,""),3)
	set cnt = cnt + 1
endwhile
set temp1->occnt = cnt1
 
select into value(tmpfile)
from dummyt d
head report
	cnt1 = 0
detail
	"MSH|^~\&|SYSTEM|SUNYSB|OCF|SUNYSB|",CURDTTMVC,"||MDM^T02|",CURDTTMVC,"|P|2.3.1|",
	CR,
	"PID|1||",mrn,"||",patientname,"|||||||||||||",encntr,"||",
	CR,
	"TXA|1|EDCOMORB^Co-Morbidity||",CURDTTMVC,"|||||",providerstr,"|||",mrn,CURDTTMVC,"|||||F|",
	for (cnt = 1 to temp1->cccnt)
		CR,
		cnt1 = cnt1 + 1
		obxcnt = trim(cnvtstring(cnt1),3)
		"OBX|",obxcnt,"|TX|EDCOMORB^Co-Morbidity||",
		"* ",temp1->cc[cnt].comorb,"  [",temp1->cc[cnt1].results,"]||||||F||||"
	endfor
	for (cnt = 1 to temp1->occnt)
		CR,
		cnt1 = cnt1 + 1
		obxcnt = trim(cnvtstring(cnt1),3)
		"OBX|",obxcnt,"|TX|EDCOMORB^Co-Morbidity||",
		"* ",temp1->oc[cnt].comorb,"||||||F||||"
	endfor
	CR
WITH nocounter,MAXCOL=5000,NOHEADING,FORMAT=undefined
 
if (curqual > 0)
	set temp->successful = 1
	set temp->msg = "Successfully created Co-Morbidity HL7."
 
	SET DCLCOM = build2("tr < $",tmpfile," -d '\000' > $",tmpfile,"tmp")
	SET LEN = SIZE(TRIM(DCLCOM))
	SET STATUS = 0
	CALL DCL(DCLCOM,LEN,STATUS)
 
	SET DCLCOM = build("mv -f $",tmpfile,"tmp $common_data/",cnvtupper(finalfile))
	SET LEN = SIZE(TRIM(DCLCOM))
	SET STATUS = 0
	CALL DCL(DCLCOM,LEN,STATUS)
 
	SET DCLCOM = build("rm -f $",tmpfile,"tmp $",tmpfile)
	SET LEN = SIZE(TRIM(DCLCOM))
	SET STATUS = 0
	CALL DCL(DCLCOM,LEN,STATUS)
 
	set cnt = 0
	while (cnt < 20)
		call pause(1)
 
		select into "nl:"
		from esi_log e
		where e.encntr_id = cnvtreal($encntrid)
			and e.create_dt_tm > datetimeadd(cnvtdatetime(curdate,curtime3),-(25.0/86400.0))
			and e.msh_msg_trig = "T02"
			and e.msh_msg_type = "MDM"
			and e.contributor_system_cd = 115416656.00	;SYSTEM
		detail
			cnt = 20
		with nocounter
 
		set cnt = cnt + 1
	endwhile
endif
 
set JSON->data = cnvtrectojson(temp)
 
record putREQUEST
(
	1 source_dir = vc
  	1 source_filename = vc
  	1 nbrlines = i4
  	1 line [*]
    	2 lineData = vc
  	1 OverFlowPage [*]
    	2 ofr_qual [*]
      		3 ofr_line = vc
  	1 IsBlob = c1
  	1 document_size = i4
  	1 document = gvc
)
 
set putRequest->source_dir = $outdev
set putRequest->IsBlob = "1"
set putRequest->document = JSON->data
set putRequest->document_size = size(putRequest->document)
 
execute eks_put_source with replace(Request,putRequest),replace(reply,putReply)
 
free record temp
free record temp1
free record JSON
 
end
go