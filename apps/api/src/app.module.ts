import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { AiJobsModule } from './features/ai-jobs/ai-jobs.module';
import { AuthModule } from './features/auth/auth.module';
import { FloorplansModule } from './features/floorplans/floorplans.module';
import { MediaModule } from './features/media/media.module';
import { PropertiesModule } from './features/properties/properties.module';
import { PublicModule } from './features/public/public.module';
import { RoomsModule } from './features/rooms/rooms.module';
import { ToursModule } from './features/tours/tours.module';
import { HealthController } from './health.controller';
import { PrismaModule } from './shared/prisma/prisma.module';
import { StorageModule } from './shared/storage/storage.module';

@Module({
  controllers: [HealthController],
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: { url: config.getOrThrow('REDIS_URL') },
      }),
    }),
    PrismaModule,
    StorageModule,
    AuthModule,
    PropertiesModule,
    RoomsModule,
    MediaModule,
    FloorplansModule,
    ToursModule,
    AiJobsModule,
    PublicModule,
  ],
})
export class AppModule {}
