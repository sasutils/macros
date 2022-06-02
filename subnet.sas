%macro subnet(in=,out=,from=from,to=to,subnet=subnet,directed=1);
/*----------------------------------------------------------------------
SUBNET - Build connected subnets from pairs of nodes.
Input Table :FROM TO pairs of rows
Output Table:input data with &subnet added
Work Tables:
  NODES - List of all nodes in input.
  NEW - List of new nodes to assign to current subnet.

Algorithm:
Pick next unassigned node and grow the subnet by adding all connected
nodes. Repeat until all unassigned nodes are put into a subnet.

To treat the graph as undirected set the DIRECTED parameter to 0.
----------------------------------------------------------------------*/
%local subnetid next getnext ;
%*----------------------------------------------------------------------
Initialize subnet id counter.
-----------------------------------------------------------------------;
%let subnetid=0;
proc sql noprint;
*----------------------------------------------------------------------;
* Create list of all nodes ;
*----------------------------------------------------------------------;
  create table nodes as
    select . as subnet, &from as node from &in where &from is not null
    union
    select . as subnet, &to as node from &in where &to is not null
  ;
*----------------------------------------------------------------------;
* Generate query to get next unassigned node into a macro variable. ;
*----------------------------------------------------------------------;
%*----------------------------------------------------------------------
Query is modified based on type of variable used for node.  This query 
is put into a macro variable so it can be used twice in the program.
-----------------------------------------------------------------------;
  select catx(' ','select ',case when type='num' then 'node'
               else 'quote(trim(node),"''")' end
             ,'into :next from nodes where subnet=.')
    into :getnext 
    from dictionary.columns
    where libname='WORK' and memname='NODES' and upcase(name)='NODE'
  ;
*----------------------------------------------------------------------;
* Get next unassigned node ;
*----------------------------------------------------------------------;
  &getnext;
%do %while (&sqlobs and not &sqlrc) ;
*----------------------------------------------------------------------;
* Set subnet to next id ;
*----------------------------------------------------------------------;
  %let subnetid=%eval(&subnetid+1);
  update nodes set subnet=&subnetid where node=&next;
  %do %while (&sqlobs) ;
*----------------------------------------------------------------------;
* Get list of connected nodes for this subnet ;
*----------------------------------------------------------------------;
    create table new as
      select distinct a.&to as node
        from &in a, nodes b, nodes c
        where a.&from= b.node
          and a.&to= c.node
          and b.subnet = &subnetid
          and c.subnet = .
    ;
%if "&directed" ne "1" %then %do;
    insert into new 
      select distinct a.&from as node
        from &in a, nodes b, nodes c
        where a.&to= b.node
          and a.&from= c.node
          and b.subnet = &subnetid
          and c.subnet = .
    ;
%end;
*----------------------------------------------------------------------;
* Update subnet for these nodes ;
*----------------------------------------------------------------------;
    update nodes set subnet=&subnetid
      where node in (select node from new )
    ;
  %end;
*----------------------------------------------------------------------;
* Get next unassigned node ;
*----------------------------------------------------------------------;
  &getnext;
%end;
*----------------------------------------------------------------------;
* Create output dataset by adding subnet number. ;
*----------------------------------------------------------------------;
  create table &out as
    select distinct a.*,b.subnet as &subnet
      from &in a , nodes b
      where a.&from = b.node
  ;
quit;
%mend subnet ;
