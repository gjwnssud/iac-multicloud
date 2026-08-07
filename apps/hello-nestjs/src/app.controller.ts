import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  getHello(): { message: string; environment: string } {
    return {
      message: 'Hello from iac-multicloud',
      environment: process.env.ENVIRONMENT ?? 'unknown',
    };
  }

  @Get('healthz')
  getHealth(): { status: string } {
    return { status: 'ok' };
  }
}
