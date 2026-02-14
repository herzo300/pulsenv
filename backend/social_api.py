# Расширения для backend API - Социальные функции
# backend/social_api.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime

from backend.database import get_db
from backend.models import Report, User, Like, Comment

router = APIRouter(prefix="/social", tags=["social"])

# ========== Лайки ==========

@router.post("/complaints/{complaint_id}/like")
async def like_complaint(
    complaint_id: int,
    user_id: int,
    db: Session = Depends(get_db)
):
    """Лайкнуть жалобу"""
    # Проверяем существование жалобы
    complaint = db.query(Report).filter(Report.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Жалоба не найдена")
    
    # Проверяем существование пользователя
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    # Проверяем, не лайкнул ли уже
    existing = db.query(Like).filter(
        Like.report_id == complaint_id,
        Like.user_id == user_id
    ).first()
    
    if existing:
        return {"success": True, "message": "Уже лайкнуто"}
    
    # Создаем лайк
    like = Like(report_id=complaint_id, user_id=user_id)
    db.add(like)
    db.commit()
    
    return {"success": True, "message": "Лайк добавлен"}

@router.delete("/complaints/{complaint_id}/like")
async def unlike_complaint(
    complaint_id: int,
    user_id: int,
    db: Session = Depends(get_db)
):
    """Убрать лайк"""
    like = db.query(Like).filter(
        Like.report_id == complaint_id,
        Like.user_id == user_id
    ).first()
    
    if like:
        db.delete(like)
        db.commit()
    
    return {"success": True}

@router.get("/complaints/{complaint_id}/likes")
async def get_likes_count(complaint_id: int, db: Session = Depends(get_db)):
    """Получить количество лайков"""
    count = db.query(Like).filter(Like.report_id == complaint_id).count()
    return {"count": count}

@router.get("/complaints/{complaint_id}/liked")
async def has_liked(complaint_id: int, user_id: int, db: Session = Depends(get_db)):
    """Проверить, лайкнул ли пользователь"""
    liked = db.query(Like).filter(
        Like.report_id == complaint_id,
        Like.user_id == user_id
    ).first() is not None
    
    return {"liked": liked}

# ========== Комментарии ==========

@router.get("/complaints/{complaint_id}/comments")
async def get_comments(complaint_id: int, db: Session = Depends(get_db)):
    """Получить комментарии к жалобе"""
    comments = db.query(Comment).filter(
        Comment.report_id == complaint_id
    ).order_by(Comment.created_at.desc()).all()
    
    return [{
        "id": c.id,
        "report_id": c.report_id,
        "user_id": c.user_id,
        "user_name": c.user.first_name if c.user else "Аноним",
        "text": c.text,
        "created_at": c.created_at.isoformat(),
        "parent_id": c.parent_id
    } for c in comments]

@router.post("/complaints/{complaint_id}/comments")
async def add_comment(
    complaint_id: int,
    text: str,
    user_id: int,
    parent_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    """Добавить комментарий"""
    # Проверяем существование жалобы
    complaint = db.query(Report).filter(Report.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Жалоба не найдена")
    
    comment = Comment(
        report_id=complaint_id,
        user_id=user_id,
        text=text,
        parent_id=parent_id
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)
    
    return {
        "id": comment.id,
        "report_id": comment.report_id,
        "user_id": comment.user_id,
        "text": comment.text,
        "created_at": comment.created_at.isoformat()
    }

@router.delete("/comments/{comment_id}")
async def delete_comment(comment_id: int, user_id: int, db: Session = Depends(get_db)):
    """Удалить комментарий"""
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    
    if not comment:
        raise HTTPException(status_code=404, detail="Комментарий не найден")
    
    # Проверяем, что пользователь - автор комментария
    if comment.user_id != user_id:
        raise HTTPException(status_code=403, detail="Нет прав на удаление")
    
    db.delete(comment)
    db.commit()
    
    return {"success": True}

# ========== Пользователи ==========

@router.post("/users")
async def create_user(
    telegram_id: Optional[int] = None,
    username: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    photo_url: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Создать или получить пользователя"""
    # Ищем по telegram_id
    if telegram_id:
        user = db.query(User).filter(User.telegram_id == telegram_id).first()
        if user:
            return {"id": user.id, "message": "Пользователь уже существует"}
    
    # Ищем по username
    if username:
        user = db.query(User).filter(User.username == username).first()
        if user:
            return {"id": user.id, "message": "Пользователь уже существует"}
    
    # Создаем нового
    user = User(
        telegram_id=telegram_id,
        username=username,
        first_name=first_name,
        last_name=last_name,
        photo_url=photo_url
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    return {
        "id": user.id,
        "telegram_id": user.telegram_id,
        "username": user.username,
        "first_name": user.first_name,
        "message": "Пользователь создан"
    }

@router.get("/users/{user_id}")
async def get_user(user_id: int, db: Session = Depends(get_db)):
    """Получить информацию о пользователе"""
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    return {
        "id": user.id,
        "telegram_id": user.telegram_id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "photo_url": user.photo_url,
        "created_at": user.created_at.isoformat()
    }

# ========== Репутация ==========

@router.get("/users/{user_id}/reputation")
async def get_user_reputation(user_id: int, db: Session = Depends(get_db)):
    """Получить репутацию пользователя"""
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    # Подсчет жалоб
    complaints_count = db.query(Report).filter(Report.user_id == user_id).count()
    resolved_count = db.query(Report).filter(
        Report.user_id == user_id,
        Report.status == "resolved"
    ).count()
    
    # Подсчет лайков на жалобах пользователя
    likes_received = db.query(Like).join(Report).filter(
        Report.user_id == user_id
    ).count()
    
    # Расчет очков
    points = (complaints_count * 10) + (resolved_count * 50) + (likes_received * 5)
    
    # Определение ранга
    rank = "Новичок"
    if points >= 5000:
        rank = "Легенда"
    elif points >= 1000:
        rank = "Городской герой"
    elif points >= 500:
        rank = "Защитник города"
    elif points >= 100:
        rank = "Активист"
    
    return {
        "user_id": user_id,
        "first_name": user.first_name,
        "points": points,
        "complaints_count": complaints_count,
        "resolved_count": resolved_count,
        "likes_received": likes_received,
        "rank": rank,
        "resolution_rate": resolved_count / complaints_count if complaints_count > 0 else 0
    }

@router.get("/users/{user_id}/rank")
async def get_user_rank(user_id: int, db: Session = Depends(get_db)):
    """Получить рейтинг пользователя (позиция в топе)"""
    # Подсчитываем сколько пользователей с большим количеством очков
    user_rep = await get_user_reputation(user_id, db)
    user_points = user_rep["points"]
    
    # Получаем всех пользователей и считаем их очки
    users = db.query(User).all()
    better_users = 0
    
    for u in users:
        if u.id == user_id:
            continue
        complaints = db.query(Report).filter(Report.user_id == u.id).count()
        resolved = db.query(Report).filter(
            Report.user_id == u.id,
            Report.status == "resolved"
        ).count()
        likes = db.query(Like).join(Report).filter(Report.user_id == u.id).count()
        points = (complaints * 10) + (resolved * 50) + (likes * 5)
        
        if points > user_points:
            better_users += 1
    
    return {"rank": better_users + 1, "total_users": len(users)}

@router.get("/users/top")
async def get_top_users(limit: int = 10, db: Session = Depends(get_db)):
    """Топ пользователей по репутации"""
    users = db.query(User).all()
    
    user_list = []
    for user in users:
        complaints_count = db.query(Report).filter(Report.user_id == user.id).count()
        resolved_count = db.query(Report).filter(
            Report.user_id == user.id,
            Report.status == "resolved"
        ).count()
        likes_received = db.query(Like).join(Report).filter(
            Report.user_id == user.id
        ).count()
        
        points = (complaints_count * 10) + (resolved_count * 50) + (likes_received * 5)
        
        rank = "Новичок"
        if points >= 5000:
            rank = "Легенда"
        elif points >= 1000:
            rank = "Городской герой"
        elif points >= 500:
            rank = "Защитник города"
        elif points >= 100:
            rank = "Активист"
        
        user_list.append({
            "id": user.id,
            "first_name": user.first_name,
            "username": user.username,
            "points": points,
            "complaints_count": complaints_count,
            "resolved_count": resolved_count,
            "rank": rank
        })
    
    # Сортируем по очкам
    user_list.sort(key=lambda x: x["points"], reverse=True)
    
    return user_list[:limit]
