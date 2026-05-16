import { RequestMethod, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { mkdir } from 'fs/promises';
import { join } from 'path';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  const uploadsPath = join(process.cwd(), 'uploads');
  await mkdir(uploadsPath, { recursive: true });
  app.useStaticAssets(uploadsPath, { prefix: '/uploads/' });

  const publicPath = join(__dirname, '..', 'public');
  app.useStaticAssets(publicPath, { prefix: '/' });

  app.setGlobalPrefix('api/v1', {
    exclude: [
      { path: 'health', method: RequestMethod.GET },
      { path: 'viewer.html', method: RequestMethod.GET },
      { path: 'tour.css', method: RequestMethod.GET },
      { path: 'tour/:slug', method: RequestMethod.GET },
    ],
  });
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('Sanaltur API')
    .setDescription('Mobile-first real estate virtual tour API')
    .setVersion('0.1')
    .addBearerAuth()
    .build();

  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, config));

  const port = Number(process.env.PORT) || 3001;
  await app.listen(port, '0.0.0.0');
  console.log(`API running on http://localhost:${port}`);
  console.log(`Uploads served at http://localhost:${port}/uploads/`);
}

bootstrap();
