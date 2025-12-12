# Use official Python image
FROM python:3.10-slim

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

# Expose the application port
EXPOSE 5000

# Run migrations automatically (optional)
# RUN python manage.py migrate

# Start Django with Gunicorn
CMD ["gunicorn", "sample.wsgi:application", "--bind", "0.0.0.0:5000"]
