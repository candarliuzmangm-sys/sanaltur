import { Global, Module } from '@nestjs/common';

import { StabilityClientService } from './stability-client.service';

@Global()
@Module({
  providers: [StabilityClientService],
  exports: [StabilityClientService],
})
export class AiModule {}
