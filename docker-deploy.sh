#!/bin/bash

# 闲鱼自动回复系统 Docker 部署脚本
# 支持快速部署和管理

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="xianyu-auto-reply"
COMPOSE_FILE="docker-compose.yml"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}�?$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}�?$1${NC}"
}

# 检查依�?
check_dependencies() {
    print_info "检查系统依�?.."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    print_success "系统依赖检查通过"
}

# 初始化配�?
init_config() {
    print_info "初始化配置文�?.."

    # 检查关键文�?
    if [ ! -f "entrypoint.sh" ]; then
        print_error "entrypoint.sh 文件不存在，Docker容器将无法启�?
        print_info "请确保项目文件完�?
        exit 1
    else
        print_success "entrypoint.sh 文件已存�?
    fi

    if [ ! -f "global_config.yml" ]; then
        print_error "global_config.yml 配置文件不存�?
        print_info "请确保配置文件存�?
        exit 1
    else
        print_success "global_config.yml 配置文件已存�?
    fi

    # 创建必要的目�?
    mkdir -p data logs backups static/uploads/images
    print_success "已创建必要的目录"
}

# 构建镜像
build_image() {
    print_info "构建 Docker 镜像..."
    echo "是否需要使用国内镜�?y/n): " && read iscn
    if [[ $iscn == "y" ]]; then
        docker-compose -f docker-compose-cn.yml build --no-cache
    else
        docker-compose build --no-cache
    fi  
    print_success "镜像构建完成"
}

# 启动服务
start_services() {
    local profile=""
    if [ "$1" = "with-nginx" ]; then
        profile="--profile with-nginx"
        print_info "启动服务（包�?Nginx�?.."
    else
        print_info "启动基础服务..."
    fi

    docker-compose $profile up -d
    print_success "服务启动完成"

    # 等待服务就绪
    print_info "等待服务就绪..."
    sleep 10

    # 检查服务状�?
    if docker-compose ps | grep -q "Up"; then
        print_success "服务运行正常"
        show_access_info "$1"
    else
        print_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
}

# 停止服务
stop_services() {
    print_info "停止服务..."
    docker-compose down
    print_success "服务已停�?
}

# 重启服务
restart_services() {
    print_info "重启服务..."
    docker-compose restart
    print_success "服务已重�?
}

# 查看日志
show_logs() {
    local service="$1"
    if [ -z "$service" ]; then
        docker-compose logs -f
    else
        docker-compose logs -f "$service"
    fi
}

# 查看状�?
show_status() {
    print_info "服务状�?"
    docker-compose ps
    
    print_info "资源使用:"
    docker stats --no-stream $(docker-compose ps -q)
}

# 显示访问信息
show_access_info() {
    local with_nginx="$1"
    
    echo ""
    print_success "🎉 部署完成�?
    echo ""
    
    if [ "$with_nginx" = "with-nginx" ]; then
        echo "📱 访问地址:"
        echo "   HTTP:  http://localhost"
        echo "   HTTPS: https://localhost (如果配置了SSL)"
    else
        echo "📱 访问地址:"
        echo "   HTTP: http://localhost:8080"
    fi
    
    echo ""
    echo "🔐 默认登录信息:"
    echo "   用户�? admin"
    echo "   密码:   admin123"
    echo ""
    echo "📊 管理命令:"
    echo "   查看状�? $0 status"
    echo "   查看日志: $0 logs"
    echo "   重启服务: $0 restart"
    echo "   停止服务: $0 stop"
    echo ""
}

# 健康检�?
health_check() {
    print_info "执行健康检�?.."
    
    local url="http://localhost:8080/health"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            print_success "健康检查通过"
            return 0
        fi
        
        print_info "等待服务就绪... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    print_error "健康检查失�?
    return 1
}

# 备份数据
backup_data() {
    print_info "备份数据..."
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份数据�?
    if [ -f "data/xianyu_data.db" ]; then
        cp data/xianyu_data.db "$backup_dir/"
        print_success "数据库备份完�?
    fi
    
    # 备份配置
    cp "$ENV_FILE" "$backup_dir/"
    cp global_config.yml "$backup_dir/" 2>/dev/null || true
    
    print_success "数据备份完成: $backup_dir"
}

# 更新部署
update_deployment() {
    print_info "更新部署..."
    
    # 备份数据
    backup_data
    
    # 停止服务
    stop_services
    
    # 拉取最新代码（如果是git仓库�?
    if [ -d ".git" ]; then
        print_info "拉取最新代�?.."
        git pull
    fi
    
    # 重新构建
    build_image
    
    # 启动服务
    start_services
    
    print_success "更新完成"
}

# 清理环境
cleanup() {
    print_warning "这将删除所有容器、镜像和数据，确定要继续吗？(y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "清理环境..."
        
        # 停止并删除容�?
        docker-compose down -v --rmi all
        
        # 删除数据目录
        rm -rf data logs backups
        
        print_success "环境清理完成"
    else
        print_info "取消清理操作"
    fi
}

# 显示帮助信息
show_help() {
    echo "闲鱼自动回复系统 Docker 部署脚本"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  init                初始化配置文�?
    echo "  build               构建 Docker 镜像"
    echo "  start [with-nginx]  启动服务（可选包�?Nginx�?
    echo "  stop                停止服务"
    echo "  restart             重启服务"
    echo "  status              查看服务状�?
    echo "  logs [service]      查看日志"
    echo "  health              健康检�?
    echo "  backup              备份数据"
    echo "  update              更新部署"
    echo "  cleanup             清理环境"
    echo "  help                显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 init             # 初始化配�?
    echo "  $0 start            # 启动基础服务"
    echo "  $0 start with-nginx # 启动包含 Nginx 的服�?
    echo "  $0 logs xianyu-app  # 查看应用日志"
    echo ""
}

# 主函�?
main() {
    case "$1" in
        "init")
            check_dependencies
            init_config
            ;;
        "build")
            check_dependencies
            build_image
            ;;
        "start")
            check_dependencies
            init_config
            build_image
            start_services "$2"
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "health")
            health_check
            ;;
        "backup")
            backup_data
            ;;
        "update")
            check_dependencies
            update_deployment
            ;;
        "cleanup")
            cleanup
            ;;

        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            print_info "快速部署模�?
            check_dependencies
            init_config
            build_image
            start_services
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函�?
main "$@"
