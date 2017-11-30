#!/bin/bash
#coding:utf-8

BACKUP_DIR=/tmp/backup
DEL_ADDFILE_BACKUP=/tmp/backup/delfile
REC_MODIFY_BACKUP=/tmp/backup/modfile
MD5SUM_DIR=/tmp/backup/md5sum_dir
LOG_DIR=/tmp/log

MD5SUM_CHECK_ERR="失败|FAILED|FAILED\ open\ or\ read|没有那个文件或目录"
PROC=${0}


INDEX=`date '+%H%M%S'`
if [[ ! -d ${BACKUP_DIR} ]];then
    mkdir -p ${BACKUP_DIR} 2>/dev/null
    chmod -R 777 ${BACKUP_DIR} 2>/dev/null
else
    BACKUP_DIR=${BACKUP_DIR}${INDEX}
    mkdir -p ${BACKUP_DIR} 2>/dev/null
    chmod -R 777 ${BACKUP_DIR} 2>/dev/null
fi 

DEL_ADDFILE_BACKUP=${BACKUP_DIR}/delfile
REC_MODIFY_BACKUP=${BACKUP_DIR}/modfile
MD5SUM_DIR=${BACKUP_DIR}/md5sum_dir
#LOG_DIR=${BACKUP_DIR}/log

mkdir ${DEL_ADDFILE_BACKUP} 2>/dev/null
mkdir ${REC_MODIFY_BACKUP} 2>/dev/null
mkdir ${MD5SUM_DIR} 2>/dev/null
mkdir ${LOG_DIR} 2>/dev/null
chmod -R 777 ${LOG_DIR}

#echo 输出颜色定义
FGRED="\033[31m"
FGGREEN="\033[32m"
FGYELLOW="\033[33m"
FGBLUE="\033[34m"
END="\033[m"

function echo_color()
{
  cur_time=`date '+%H:%M:%S'`
  case ${1} in
    'RED' )
      echo -e ${FGRED}"[-][${cur_time}] "${2}${END}
      ;;
    'GREEN' )
      echo -ne ${FGGREEN}"[*][${cur_time}] "${2}${END}"${3}"
      ;;
    'YELLOW' )
      echo -e ${FGYELLOW}"[-][${cur_time}] "${2}${END}
      ;;
    'BLUE' )
      echo -ne ${FGBLUE}"[*][${cur_time}] "${2}${END}"${3}"
      ;;
      * )
      echo ${FGBLUE}"[-][${cur_time}] Give me something to show..."${END}
      ;;
  esac
}

function usage()
{
  #使用帮助
  #要求参数必须是目录的绝对地址
  #目录不要以 "/"结束
  echo_color 'RED' "bash ./${0} <dir> [<dir>]...[<dir>]"
}

#获取待备份目录的目录名，用目录来作为备份文件的文件名
function get_filename()
{
  #如果目录是
  if [[ ${1} == "./" ]];then
    cwd=`pwd`
    filename=`basename ${cwd}`
  elif [ -d ${1} ]; then
    filename=`basename ${1}`
  else
    echo_color 'RED' "Bad directory name"
    exit 0
  fi
  echo $filename    #返回文件名
}


#初始化函数
#备份恢复的初始化，对备份目录进行md5sum计算,copy待备份目录的copy
function initialize()
{
    filename=`get_filename ${1}`
    cur_init=`date '+%H:%M:%S'`

    MOD_LOG=${LOG_DIR}/"modifedlog_${filename}.log"
    DEL_LOG=${LOG_DIR}/"deletelog_${filename}.log"
    MON_LOG=${LOG_DIR}/"monitorlog_${filename}.log"
    touch ${MOD_LOG} 2>/dev/null
    chmod 777 ${MOD_LOG}
    touch ${DEL_LOG} 2>/dev/null
    chmod 777 ${DEL_LOG}
    touch ${MON_LOG} 2>/dev/null
    chmod 777 ${MON_LOG}
    find ${1} -type f -print0 | xargs -0 md5sum > ${MD5SUM_DIR}/"orig_"${filename}".md5" 2>/dev/null

    #遍历所有文件，并计算md5sum，存储到文件中
    #find ${1} -perm -220 -not -empty -type d -print0 |xargs -0 -i find {} -type f -print0 | xargs -0 md5sum > ${MD5SUM_DIR}/"orig_"${filename}".md5" 2>/dev/null
    echo_color "YELLOW" " -> [COPY2BACKUP] ${1} to ${BACKUP_DIR}"
    echo "[${cur_init}][COPY2BACKUP] ${1} to ${BACKUP_DIR}" >> $MON_LOG
    cp -r "${1}" "${BACKUP_DIR}"
    find ${BACKUP_DIR}/${filename} -type f -print0 | xargs -0 md5sum > ${MD5SUM_DIR}/"backup_"${filename}".md5" 2>/dev/null
}

function file_be_modified_and_recover()
{
    
    filename=`get_filename $1`
    cur_recover=`date '+%H:%M:%S'`

    #md5sum校验失败，可能有文件被修改，所以把被修改的文件取出
    #md5_check_result=`md5sum -c $MD5SUM_DIR/'orig_'$filename.md5 | egrep "$MD5SUM_CHECK_ERR" | awk -F ":" '{print $1}' |sed '/^$/d'`

    md5_check_result=`md5sum -c ${MD5SUM_DIR}/'orig_'${filename}".md5" 2>/dev/null | egrep "${MD5SUM_CHECK_ERR}" | awk -F ":" '{print $1}' |sed '/^$/d'` 2>/dev/null
    if [[ -z ${md5_check_result} ]];then
      echo_color 'GREEN' " -> Nothing changed...-" "\r"
    else
      for f in `echo ${md5_check_result} | awk '{print $1" "$2}'`;do
        file_name=`basename ${f}`
        dir_path=`dirname ${f}`
          
        echo_color 'RED' " -> [RECOVER] ${f}"         #stdout
        echo "[-] [${cur_recover}] -> [RECOVER] ${f}" >> ${MOD_LOG}
          
        if [[ -e ${f} ]]; then
          cp -f ${f} ${REC_MODIFY_BACKUP} 2>/dev/null
        fi
        cp -f ${BACKUP_DIR}/${filename}/${dir_path##*$filename}/${file_name} "${f}" 2>/dev/null
      done 
    fi
}

function file_be_added_and_remove()
{
  filename=`get_filename ${1}`
  cur_remove=`date '+%H:%M:%S'`
  find ${1} -type f -print0 | xargs -0 md5sum > ${MD5SUM_DIR}/"new_"${filename}".md5" 2>/dev/null
  
  #find ${1} -perm -220 -not -empty -type d -print0 |xargs -0 -i find {} -type f -print0 | xargs -0 md5sum > ${MD5SUM_DIR}/"new_"${filename}".md5" 2>/dev/null

  #比较新md5sum 与原 md5sum 如果有新增，则删除新增文件
  DIFF=`grep -F -v -f $MD5SUM_DIR/"orig_"$filename".md5" ${MD5SUM_DIR}/"new_"${filename}".md5" 2>/dev/null` 
  if [[ -n ${DIFF} ]]; then
    echo_color 'RED' " -> [REMOVE] `echo "${DIFF}"| awk '{print $2}'|sed '/^$/d' | xargs -i echo {}`"
    echo "${DIFF}"| awk '{print $2}'|sed '/^$/d'|xargs -i cp -rf {} ${DEL_ADDFILE_BACKUP} 2>/dev/null     #先备份再删除
    echo "${DIFF}"| awk '{print $2}'|sed '/^$/d'|xargs -i echo "[${cur_remove}][REMOVE] {}" >>${DEL_LOG}                          #保存路径
    echo "${DIFF}"| awk '{print $2}'|sed '/^$/d'|xargs -i rm -rf "{}" 2>/dev/null                        #删除新增加的文件
  else
    echo_color 'GREEN' " -> Nothing changed...+" "\r"
  fi
}



function fix_from_backup()
{
    filename=`get_filename ${1}`
    cur_fix_time=`date '+%H:%M:%S'`
    md5_fix_check=`md5sum -c ${MD5SUM_DIR}/"backup_"${filename}".md5" 2>/dev/null | egrep "${MD5SUM_CHECK_ERR}" | awk -F ":" '{print $1}' |sed '/^$/d'` 2>/dev/null
    if [[ -z ${md5_fix_check} ]]; then
      echo_color 'GREEN' " -> Nothing changed...-" "\r"
    else
      find ${BACKUP_DIR}/${filename} -type f -print0 | xargs -0 md5sum > $MD5SUM_DIR/"backup_"$filename.md5 2>/dev/null
      for fix in `echo ${md5_fix_check} | awk '{print $1" "$2}'`;do
        file_name=`basename ${fix}`
        dir_path=`dirname ${fix}`
          
        echo_color 'RED' " -> [FIX_RECOVER] ${fix}"         #stdout
        echo "[-] [${cur_fix_time}] -> [FIX_RECOVER] ${fix}" >> ${MON_LOG}
        echo ${fix} >> ${MOD_LOG}
        if [[ -e ${fix} ]];then
          cp -f ${fix} ${1}/${dir_path##*$filename}/${file_name} 2>/dev/null
        fi
        sed -e "s:${BACKUP_DIR}/${filename}:${1}:g" ${MD5SUM_DIR}/"backup_"${filename}".md5" > ${MD5SUM_DIR}/'orig_'${filename}".md5" 2>/dev/null
      done
    fi
}


#-----------------------------------------------------------#
function main()
{
  for i in $@;do
    initialize ${i}
  done

  while true;
  do
    for j in $@ ;do
      cat /tmp/bashell/shell_addr.txt |xargs -n 1 -i rm -f {}
      fix_from_backup ${j}                    #备份文件被修改时更新
      file_be_modified_and_recover ${j}       #web 修改时从备份覆盖
      file_be_added_and_remove ${j}         #有文件添加时删除文件
    done
    sleep 1
  done

}

#-----------------------------------------------------------------#
main $@