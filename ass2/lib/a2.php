<?php
// COMP3311 18s1 Assignment 2
// Functions for assignment Tasks A-E
// Written by <<Yuexuan Liu>> (z5093599), May 2018

// assumes that defs.php has already been included


// Task A: get members of an academic object group

// E.g. list($type,$codes) = membersOf($db, 111899)
// Inputs:
//  $db = open database handle
//  $groupID = acad_object_group.id value
// Outputs:
//  array(GroupType,array(Codes...))
//  GroupType = "subject"|"stream"|"program"
//  Codes = acad object codes in alphabetical order
//  e.g. array("subject",array("COMP2041","COMP2911"))

function membersOf($db,$groupID)
{
	$q = "select * from acad_object_groups where id = %d";
	$grp = dbOneTuple($db, mkSQL($q, $groupID));
	$q2 = "select * from qone(%d)";
	$code = dbAllTuples($db,mkSQL($q2,$groupID));
	$r = array();
	foreach ($code as $c) $r[] = $c[0];
	
	return array($grp["gtype"],$r); // stub
}


// Task B: check if given object is in a group

// E.g. if (inGroup($db, "COMP3311", 111938)) ...
// Inputs:
//  $db = open database handle
//  $code = code for acad object (program,stream,subject)
//  $groupID = acad_object_group.id value
// Outputs:
//  true/false

function inGroup($db, $code, $groupID)
{
	$q = "select * from qtwo(%s,%d)";
        $r = dbOneValue($db, mkSQL($q, $code,$groupID));
	return $r;
}


// Task C: can a subject be used to satisfy a rule

// E.g. if (canSatisfy($db, "COMP3311", 2449, $enr)) ...
// Inputs:
//  $db = open database handle
//  $code = code for acad object (program,stream,subject)
//  $ruleID = rules.id value
//  $enr = array(ProgramID,array(StreamIDs...))
// Outputs:

function canSatisfy($db, $code, $ruleID, $enrolment)
{
	$a = array("RQ","DS","CC","PE","FE","GE");
	$q1 = "select type from rules where id = %d";
	$q2 = "select * from checkPatGE(%d)";
	$q3 = "select * from validProGE(%s,%d)";
	$q4 = "select * from checkRules(%s,%d)";
        $q5 = "select * from validStGE(%s,%d)";
	$q6 = "select * from checkGEingroup(%s,%d)";

        $r = dbOneValue($db, mkSQL($q1, $ruleID));
	$g = dbOneValue($db, mkSQL($q2, $ruleID));
        $pe = dbOneValue($db, mkSQL($q3, $code,$enrolment[0]));
        $cr = dbOneValue($db, mkSQL($q4, $code,$ruleID));
	$gi = dbOneValue($db, mkSQL($q6, $code,$ruleID));

	if(in_array($r,$a)){
//pattern is GEN
		if($g){
//only have program
			if(empty($enrolment[1])){
				//ge can't satify
				if(!$pe){
					$p = 0;
				}else{ 
					if(!$gi){ $p = 0; }
					else { $p = 1;}
				}
			}else{
				$p = 1;
				foreach($enrolment[1] as $key){
					$se = dbOneValue($db, mkSQL($q5, $code, $key));
					if(!$se){$p = 0;}
				}
				if(!$gi){ $p = 0; }
			}
		}else{
			$p = dbOneValue($db, mkSQL($q4, $code,$ruleID));
		}
	} else {
		$p = 0;
	}
	return $p; // stub
}


// Task D: determine student progress through a degree

// E.g. $vtrans = progress($db, 3012345, "05s1");
// Inputs:
//  $db = open database handle
//  $stuID = People.unswid value (i.e. unsw student id)
//  $semester = code for semester (e.g. "09s2")
// Outputs:
//  Virtual transcript array (see spec for details)

function progress($db, $stuID, $term)
{
//temporary query have to deal with sem issue
	$exactT = "select * from exactTerm(%d,%d)";
	$termID = dbOneValue($db, mkSQL($exactT,$stuID,$term));

	$q = "select id,program from Program_enrolments where student=%d and semester=%d";
	$pe = dbOneTuple($db, mkSQL($q,$stuID,$termID));
//if (empty($pe))exit("Student ($stuID) not enrolled in $sem\n");
	$q = "select stream from Stream_enrolments where partof=%d";
	$r = dbQuery($db, mkSQL($q, $pe[0]));
	$streams = array();
	while ($t = dbNext($r)) { $streams[] = $t[0];}
	$enrolment = array($pe[1],$streams); // ProgID,StreamIDs

	$q = "select * from updateTrans(%d,%d)";
	$q1 = "select * from rulesRightOrder(%d,%d)";
	if($term < $termID){
		$a = dbAllTuples($db, mkSQL($q, $stuID,$termID));
	}else{
        	$a = dbAllTuples($db, mkSQL($q, $stuID,$term));
	}
	$r = dbAllTuples($db, mkSQL($q1, $stuID,$termID));
//print_r($r); // DBUG
//print_r($a);
	$b = array();
	foreach($r as $j=>$key){
		$r[$j][4] = 0;
	}
	foreach($a as $j=>$key){
		if(!empty($key[0])){
			for($i = 0; $i < 6; $i++){
				$b[$j][] = $key[$i]; 
			}
		} else {
			if($key[name] == "No WAM available"){
				$b[$j][0] = "Overall WAM";
				$b[$j][1] = null;
				$b[$j][2] = null;
 			}else{	
				for($i = 0; $i < 6; $i++){
					if(!empty($key[$i])){ $b[$j][] = $key[$i]; }
				}
			}
		}
                if(!empty($key[0])){
			if($key[grade] == "FL"){
				$b[$j][6] = "Failed. Does not count";
			} elseif(empty($key[mark]) and empty($key[grade])){
				$b[$j][6] = "Incomplete. Does not yet count";
			} else{
				foreach($r as $i=>$rule){
					$sat = canSatisfy($db, $key[code], $rule[0], $enrolment);
					if($sat){ 
                                                $d = $key[uoc]+ $rule[4];
						if(!empty($rule[max])){
							if($d <= $rule[max]){ $r[$i][4] = $d; $require = ruleName($db,$rule[0]);break;}
							else{ $sat = 0; }
						}else{
						        $r[$i][4] = $d; 
							$require = ruleName($db,$rule[0]);break;
						}
						
					}
				}
				if($sat == 0){ $require = "Fits no requirement. Does not count"; }
				$b[$j][6] = $require;
			}
		} 
	}
//print_r($b);
	$curr = sizeof($b);
	foreach($r as $rule){
		if(empty($rule[max])){
			if($rule[4] < $rule[min]){ $d = $rule[min] - $rule[4];}
			else{ $d = -1;}
		}else{$d = $rule[max] - $rule[4];}
		$name = ruleName($db,$rule[0]);
		if($d > 0){
			$b[$curr][0] = sprintf("%d UOC so far; need %d UOC more",$rule[4],$d);
			$b[$curr][1] = sprintf("%s",$name);
			$curr++;
		}
	}

	return $b; // stub
}


// Task E:

// E.g. $advice = advice($db, 3012345, 162, 164)
// Inputs:
//  $db = open database handle
//  $studentID = People.unswid value (i.e. unsw student id)
//  $currTermID = code for current semester (e.g. "09s2")
//  $nextTermID = code for next semester (e.g. "10s1")
// Outputs:
//  Advice array (see spec for details)

function advice($db, $studentID, $currTermID, $nextTermID)
{

	$q = "select * from exactTerm(%d,%d)";
	$term = dbOneValue($db,mkSQL($q,$studentID,$currTermID));

	$q = "select * from findcareer(%d,%d)";
	$career = dbOneValue($db,mkSQL($q,$studentID,$term));

	$q = "select * from rightOrder(%d,%d)";
	$all_rules = dbQuery($db,mkSQL($q,$studentID,$term));
	$r = array();
	$limit = array();
	while($t = dbNext($all_rules)){
		if($t[type] == "CC" or $t[type] == "PE" or $t[type] == "FE" or $t[type] == "GE" or $t[type] == "LR"){
			$r[] = $t;
		}else {
			$limit[] = $t;
		}
	}
        $q = "select * from uocwam(%d,%d)";
        $u = dbOneTuple($db,mkSQL($q,$studentID,$nextTermID));
	$wam = $u[mark];
	$q = "select * from transtable(%d,%d)";
	$u = dbQuery($db,mkSQL($q,$studentID,$currTermID));
	$uoc = 0;
	while($uo = dbNext($u)){
                $uoc = $uoc + $uo[uoc];
        }
	$result = array();
	$curr = 0;
	foreach($r as $cour){
		if($cour[type] == "FE"){
			$fn = array();
			$num = array();
			$fn = progress($db,$studentID,$nextTermID);
			foreach($fn as $e){
				switch(count($e)){
				case 2:
					if(preg_match("/^[Ff]/",$e[1])){
					preg_match("/(\d+) UOC so far; need (\d+) UOC more/",$e[0],$num);
					}
				}
			}
			if($num[2] > 0){ 
				$result[$curr][0] = "Free....";
				$result[$curr][1] = "Free Electives (many choices)";
				$result[$curr][2] = $num[2];
				$name = ruleName($db,$cour[ruleid]);
				$result[$curr][3] = $name;
				$curr++;
			}
		} elseif ($cour[type] == "GE"){
			foreach($limit as $li){
                                $num = array();
				$q = "select * from getmrpat(%d)";
				$patt = dbQuery($db,mkSQL($q,$li[ruleid]));
				while($p = dbNext($patt)){
					if(preg_match("/^GEN/",$p[0])){
						if($li[min] <= $uoc){
							$m = array();
                        				$m = progress($db,$studentID,$nextTermID);
					                foreach($m as $mr){
								switch(count($mr)){
								case 2:
									if(preg_match("/^[Gg]/",$mr[1])){
			                                        	preg_match("/(\d+) UOC so far; need (\d+) UOC more/",$mr[0],$num);
									}
								}
							}
							if($num[2] > 0){
								$result[$curr][0] = "GenEd...";
								$result[$curr][1] = "General Education (many choices)";
								$result[$curr][2] = $num[2];
								$name = ruleName($db,$cour[ruleid]);
								$result[$curr][3] = $name;
								$curr++;
							}
						}
					}
				}
			}
		} elseif ($cour[type] == "LR"){
		} else {
			$q = "select * from afterExCourse(%d,%d,%d,%d,%s,%d,%d)";
			$subject = dbQuery($db,mkSQL($q,$cour[ruleid],$studentID,$currTermID,$nextTermID,$career,$uoc,$wam));
			while($s = dbNext($subject)){
				$can = 1;
				foreach($limit as $li){
					$q = "select * from getmrpat(%d)";
					$patt = dbQuery($db,mkSQL($q,$li[ruleid]));
					while($p = dbNext($patt)){
						$p[0] = preg_replace("/#/",".",$p[0]);
						if(preg_match("/$p[0]/",$s[0])){
							if($li[min]> $uoc){
								$can = 0;
							}
						}
					}
				}
				$already = array();
				foreach($result as $res){
					$already[] = $res[0];
				}
				$ina = in_array($s[0],$already);
				if($can == 1 and $ina != 1){
					$q = "select code,name,uoc from subjects where code::text ~ %s";
					$sub_name = dbOneTuple($db,mkSQL($q,$s[0]));
					$result[$curr][0] = $sub_name[code];
					$result[$curr][1] = $sub_name[name];
					$result[$curr][2] = $sub_name[uoc];
	                                $name = ruleName($db,$cour[ruleid]);
//echo "im doing rule $cour[ruleid] with name $name\n";
					$result[$curr][3] = $name;
					$curr++;
				}
			}			
		}
	}

	return $result; // stub
}
?>
