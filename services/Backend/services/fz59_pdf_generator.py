# -*- coding: utf-8 -*-
"""Заглушки PDF-генератора ФЗ-59: исходный файл был повреждён (битая
кодировка + потерянные кавычки). Восстановлен как безопасный стаб."""

import os
from datetime import datetime

NIZHNEVARTOVSK_DEPARTMENTS = {
    "uk_1": "Управляющая компания №1 г. Нижневартовск",
    "uk_2": "Управляющая компания №2 г. Нижневартовск",
    "zhkh": "Департамент ЖКХ Администрации г. Нижневартовска",
    "adm": "Главе города Нижневартовска Кощенко Д.А.",
}


def generate_fz59_pdf(
    output_path,
    applicant_name,
    applicant_address,
    applicant_phone,
    department_key,
    category,
    description,
    location_address,
    lat=0.0,
    lng=0.0,
):
    return output_path
